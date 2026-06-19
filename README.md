# Trustline EVM SDK

A Solidity SDK for protecting EVM-compatible smart contracts from unauthorized access and malicious transactions by integrating Trustline's Oracle with multiple on-chain data sources.

## Features

- ✅ **Transaction Validation** - Validate blockchain transactions with customizable policies
- ✅ **Sanctions Checking** - Verify addresses against sanctions lists
- ✅ **Multiple Validation Modes** - Support for Dapp, Uniswap V4, Morpho V2, and ERC-3643 modes
- ✅ **Address Verification** - Check sender and recipient addresses for compliance
- ✅ **Upgradeable Support** - Fully compatible with upgradeable smart contracts
- ✅ **ERC20 & ERC3643 Support** - Secure operations on standard token contracts
- ✅ **Proxy Deployment** - Automatic Validation Engine proxy deployment
- ✅ **Flexible Integration** - Use existing Validation Engine or deploy new instance

## Installation

```sh
npm install @trustline.id/evmsdk
```

## Architecture

Validation is performed through a small set of on-chain/off-chain components:

- **Your contract** — Inherits from `Trustlined` and calls `requireTrustline()` before sensitive operations (or `checkTrustlineStatus()` when a non-enforcing query is needed). It holds the address of a **Validation Engine proxy**.
- **Validation Engine proxy** — An ERC1967 proxy that your contract talks to. It delegates all calls to the **Validation Engine logic** contract, so the implementation can be upgraded without changing your contract’s configuration. This proxy is deployed automatically when your contract is deployed or initialized, if you do not provide an existing proxy. **Do not deploy this proxy manually** - manual deployment risks a separate, non-atomic `initialize` step and an uninitialized or misconfigured engine.
- **Validation Engine logic** — The implementation contract that runs Trustline's transaction validation logic. It verifies certificates issued by **Trustline's Oracle backend** (and optionally consults other oracles) to decide whether a transaction and its addresses are authorized. Trustline deploys it on supported blockchains.
- **Trustline's Oracle backend** — Trustline’s off-chain service that issues validation certificates to the on-chain Validation Engine.
- **Other oracles** — The Validation Engine can aggregate data from additional on-chain oracles (e.g. sanctions lists) so validation uses multiple data sources.

In short: your contract → Validation Engine proxy → Validation Engine logic → Trustline Oracle backend + other oracles. You only configure your contract with the logic address or an already-deployed proxy (for advanced use cases) at deploy time; the rest is handled by Trustline’s infrastructure.

## Quick Start

### Basic Contract Integration

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {Trustlined} from "@trustline.id/evmsdk/contracts/Trustlined.sol";

contract MyContract is Trustlined {
    constructor(
        address trustlineValidationEngineLogic,
        address trustlineValidationEngineProxy
    ) Trustlined(trustlineValidationEngineLogic, trustlineValidationEngineProxy) {}

    function transfer(address recipient, uint256 amount) external {
        // Validate sender only
        requireTrustline();
        
        // Your transfer logic here
        // ...
    }

    function transferWithRecipientCheck(address recipient, uint256 amount) external {
        // Validate both sender and recipient
        address[] memory addresses = new address[](1);
        addresses[0] = recipient;
        requireTrustline(addresses);
        
        // Your transfer logic here
        // ...
    }
}
```

### Using Existing Validation Engine Proxy

If you already have a Validation Engine proxy that was **previously deployed atomically** by another `Trustlined` contract (via the auto-deploy path below), you can reuse it:

```solidity
contract MyContract is Trustlined {
    constructor(address existingValidationEngineProxy) 
        Trustlined(address(0), existingValidationEngineProxy) {}
    
    // If you pass address(0) for logic, the provided proxy will be used
}
```

> **Important:** Never deploy a Validation Engine proxy manually (e.g. with a standalone `ERC1967Proxy` deployment followed by a separate `initialize` call). Only use proxies created by `Trustlined` during contract deployment, which deploys the proxy and calls `initialize` in a single atomic step. A manually deployed proxy may be left uninitialized or initialized by the wrong account.

### Deploying New Validation Engine Proxy

To deploy a new Validation Engine proxy, pass the Trustline logic address and `address(0)` for the proxy. Deployment and initialization happen **atomically** during your contract's deployment - do not deploy the proxy yourself:

```solidity
contract MyContract is Trustlined {
    constructor(address validationEngineLogic) 
        Trustlined(validationEngineLogic, address(0)) {}
    
    // A new Validation Engine proxy will be deployed automatically during contract deployment
}
```

## API Reference

### Contract: `Trustlined`

Base abstract contract that provides transaction validation functionality. Inherit from this contract to add Trustline validation to your smart contracts.

#### Constructor

```solidity
constructor(
    address trustlineValidationEngineLogic,
    address trustlineValidationEngineProxy
)
```

**Parameters:**
- `trustlineValidationEngineLogic`: The Validation Engine logic contract address. Used only if `trustlineValidationEngineProxy` is `address(0)`. If both are provided, `trustlineValidationEngineProxy` takes precedence.
- `trustlineValidationEngineProxy`: Optional Validation Engine proxy address. If provided (non-zero), it will be used directly. If `address(0)`, a new proxy will be deployed using the logic contract.

**Behavior:**
- If `trustlineValidationEngineProxy` is non-zero: Uses the provided proxy directly (must have been deployed atomically by `Trustlined`, with `defaultAdmin` set to the caller)
- If `trustlineValidationEngineProxy` is `address(0)`: Deploys a new ERC1967 proxy using `trustlineValidationEngineLogic` and calls `initialize` in the same transaction - **never deploy this proxy manually**

#### Functions

`requireTrustline` and `checkTrustlineStatus` serve different roles:

| Function | Role | Enforces compliance? |
|----------|------|----------------------|
| `requireTrustline(...)` | **Enforcing call** — reverts if the transaction is not compliant | Yes |
| `checkTrustlineStatus(...)` | **Query** — returns `true` or `false` without reverting | No |

Use `requireTrustline()` to guard state-changing operations. Use `checkTrustlineStatus()` only when you need the result (e.g. a `view` function, or conditional branching). If you call `checkTrustlineStatus()` before a state-changing operation and want to block non-compliant callers, you **must** wrap it: `require(checkTrustlineStatus(), "...")`. Calling `checkTrustlineStatus()` alone does not prevent execution.

##### `requireTrustline()`

**Enforcing call.** Requires a trusted transaction and a non-sanctioned `msg.sender`. Reverts if the transaction is not compliant.

```solidity
function requireTrustline() internal
```

**Usage:**
```solidity
function transfer(uint256 amount) external {
    requireTrustline(); // Validates msg.sender only
    // Your logic here
}
```

##### `requireTrustline(address[] memory addresses)`

Requires a trusted transaction and non-sanctioned `msg.sender` + addresses. Reverts if the transaction is not compliant.

```solidity
function requireTrustline(address[] memory addresses) internal
```

**Parameters:**
- `addresses`: An array of addresses that will be verified by the policy (e.g., recipients, token addresses)

**Usage:**
```solidity
function payTokens(address recipient, address token, uint256 amount) external {
    address[] memory addresses = new address[](2);
    addresses[0] = recipient;
    addresses[1] = token;
    requireTrustline(addresses); // Validates msg.sender, recipient, and token
    // Your logic here
}
```

##### `checkTrustlineStatus()`

Checks whether a transaction is trusted and verifies `msg.sender` against sanctions lists. Returns `true` if compliant, `false` otherwise.

```solidity
function checkTrustlineStatus() internal view returns (bool)
```

**Usage:**
```solidity
function canTransfer() external view returns (bool) {
    return checkTrustlineStatus();
}
```

##### `checkTrustlineStatus(address[] memory addresses)`

Checks whether a transaction is trusted and verifies `msg.sender` + addresses against sanctions lists. Returns `true` if compliant, `false` otherwise.

```solidity
function checkTrustlineStatus(address[] memory addresses) internal view returns (bool)
```

**Parameters:**
- `addresses`: An array of addresses that will be verified by the policy

**Usage:**
```solidity
function canPay(address recipient) external view returns (bool) {
    address[] memory addresses = new address[](1);
    addresses[0] = recipient;
    return checkTrustlineStatus(addresses);
}
```

#### Public Variables

##### `validationEngine`

The Trustline ValidationEngine contract address. This is set during contract initialization.

```solidity
IValidationEngine public validationEngine;
```

#### Events

##### `ValidationEngineDeployed`

Emitted when a new Validation Engine proxy is deployed for this client contract.

```solidity
event ValidationEngineDeployed(
    address indexed client,
    address indexed engineProxy,
    address indexed logic,
    address initialOwner
);
```

**Parameters:**
- `client`: The address of the integrating contract (i.e., the contract inheriting from Trustlined)
- `engineProxy`: The freshly deployed ERC1967 proxy address for the Validation Engine instance
- `logic`: The Validation Engine implementation (logic) contract the proxy points to at deployment time
- `initialOwner`: The address passed to the engine's `initialize(address)` call (typically the deployer/initializer)

##### `ValidationEngineAdopted`

Emitted when an existing Validation Engine proxy is adopted by this client contract.

```solidity
event ValidationEngineAdopted(
    address indexed client,
    address indexed engineProxy
);
```

**Parameters:**
- `client`: The address of the integrating contract (i.e., the contract inheriting from Trustlined)
- `engineProxy`: The Validation Engine proxy address being reused

## Validation Modes

The SDK supports different validation modes for various DeFi protocols. These can be used with the advanced `IValidationEngine` interface methods:

- **`Dapp`** (default) - Custom dapp validation mode
- **`UniswapV4`** - Uniswap V4 protocol validation
- **`MorphoV2`** - Morpho V2 protocol validation
- **`ERC3643`** - ERC-3643 token standard validation

## Examples

### Payment Firewall

A complete example that ensures all payments are compliant. See the [PaymentFirewall.sol](contracts/examples/PaymentFirewall.sol) contract for the full implementation.


## Upgradeable Contracts

The `Trustlined` contract is fully compatible with upgradeable contracts using OpenZeppelin's upgradeable pattern:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Trustlined} from "@trustline.id/evmsdk/contracts/Trustlined.sol";

contract UpgradeableContract is Initializable, Trustlined {
    function initialize(
        address trustlineValidationEngineLogic,
        address trustlineValidationEngineProxy
    ) public initializer {
        __Trustlined_init(trustlineValidationEngineLogic, trustlineValidationEngineProxy);
    }

    function transfer(address to, uint256 amount) external {
        address[] memory addresses = new address[](1);
        addresses[0] = to;
        requireTrustline(addresses);
        // Your logic here
    }
}
```

## Build

Build the SDK:

```sh
npm run build
```

This generates:
- `artifacts/` - Compiled contract artifacts
- `dist/bundle.js` - Browser bundle (for JavaScript usage)

Compile contracts only:

```sh
npm run compile
```

## Security Considerations

- Never deploy a Validation Engine proxy manually - always let `Trustlined` deploy and initialize it atomically, or reuse a proxy previously created that way
- Validation Engine logic and proxy addresses must be genuine contracts — EIP-7702 delegated EOAs (code prefix `0xef0100`) are rejected
- Always validate addresses that receive funds or tokens
- Use `requireTrustline(addresses[])` when checking recipients
- Use `requireTrustline()` for sender-only validation when appropriate
- The Validation Engine must be properly configured and deployed

## License

MIT

## Links

- **Homepage:** https://www.trustline.id
- **Repository:** https://github.com/TrustLine-id/evmsdk
- **Issues:** https://github.com/TrustLine-id/evmsdk/issues

## Support

Not sure how to get started? Contact us at contact@trustline.id
