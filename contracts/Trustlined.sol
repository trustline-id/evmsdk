// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IAccessControlDefaultAdminRules} from "@openzeppelin/contracts/access/extensions/IAccessControlDefaultAdminRules.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IValidationEngine} from "./interfaces/IValidationEngine.sol";
import {IValidationEngineInitializer} from "./interfaces/IValidationEngineInitializer.sol";

/// @title Trustline's Base Contract
/// @author Trustline
/// @notice This library provides functions for verifying the trust status of a transaction
/// @dev Validation Engine proxies must not be deployed manually. Use the auto-deploy path (logic + zero proxy)
///      so the ERC1967 proxy is created and `initialize` runs atomically, or reuse a proxy previously deployed that way.
abstract contract Trustlined {
    /// @notice Emitted when a new Validation Engine proxy is deployed for this client contract.
    /// @dev `client` is the address of the integrating contract (i.e., the contract inheriting from Trustlined).
    /// @dev `engineProxy` is the freshly deployed ERC1967 proxy address for the Validation Engine instance.
    /// @dev `logic` is the Validation Engine implementation (logic) contract the proxy points to at deployment time.
    /// @dev `initialOwner` is the address passed to the engine's `initialize(address)` call (typically the deployer/initializer).
    event ValidationEngineDeployed(
        address indexed client,
        address indexed engineProxy,
        address indexed logic,
        address initialOwner
    );

    /// @notice Emitted when an existing Validation Engine proxy is adopted by this client contract.
    /// @dev `client` is the address of the integrating contract (i.e., the contract inheriting from Trustlined).
    /// @dev `engineProxy` is the Validation Engine proxy address being reused.
    event ValidationEngineAdopted(
        address indexed client,
        address indexed engineProxy
    );

    /// @notice The Trustline ValidationEngine contract address. It must be set before any of the provided functions can be used
    /// @dev Multiple dapps can share the same ValidationEngine contract
    /// @dev This contract is set by the owner and must implement the IValidationEngine interface
    IValidationEngine public validationEngine;

    /// @dev Both a constructor and initializer functions are defined to support both upgradeable and non-upgradeable deployment scenarios
    /// @param trustlineValidationEngineLogic The Validation Engine logic contract address for deploying a proxy (used only if validationEngineAddress is zero)
    /// @param trustlineValidationEngineProxy Optional Validation Engine proxy address. If provided (non-zero), it must have been deployed atomically by `Trustlined` (not manually). If `address(0)`, a new proxy is deployed and initialized in the same transaction.
    constructor(address trustlineValidationEngineLogic, address trustlineValidationEngineProxy) {
        __Trustlined_init(trustlineValidationEngineLogic, trustlineValidationEngineProxy);
    }

    function __Trustlined_init(address logic, address proxy) internal {
        __Trustlined_init_unchained(logic, proxy);
    }

    function __Trustlined_init_unchained(address logic, address proxy) internal {
        require(address(validationEngine) == address(0), "Already initialized");

        if (proxy != address(0)) {
            // Use the provided Validation Engine proxy
            require(proxy.code.length > 0, "Proxy is not a contract");
            _assertValidationEngine(proxy);
            require(
                IAccessControlDefaultAdminRules(proxy).defaultAdmin() == msg.sender,
                "Invalid validation engine admin"
            );
            validationEngine = IValidationEngine(proxy);

            emit ValidationEngineAdopted(address(this), proxy);
        } else {
            // Deploy a new Validation Engine proxy and initialize it atomically (never deploy manually)
            require(logic.code.length > 0, "Logic is not a contract");

            address initialOwner = msg.sender;

            // Deployment of the Validation Engine proxy
            bytes memory data = abi.encodeCall(IValidationEngineInitializer.initialize, (initialOwner));
            address proxy_ = address(new ERC1967Proxy(logic, data));

            _assertValidationEngine(proxy_);
            validationEngine = IValidationEngine(proxy_);

            emit ValidationEngineDeployed(address(this), proxy_, logic, initialOwner);
        }
    }

    /// @notice Checks whether a transaction is trusted and verifies msg.sender + addresses[] against sanctions lists
    /// @dev Does not enforce compliance. Use `requireTrustline(...)` to enforce.
    /// @param addresses An array of addresses that will be verified by the policy
    function checkTrustlineStatus(address[] memory addresses) internal view returns (bool) {
        return validationEngine.checkTrustlineStatus(msg.sender, msg.value, msg.data, addresses);
    }

    /// @notice Checks whether a transaction is trusted and verifies msg.sender against sanctions lists
    /// @dev Does not enforce compliance. Use `requireTrustline(...)` to enforce.
    function checkTrustlineStatus() internal view returns (bool) {
        return validationEngine.checkTrustlineStatus(msg.sender, msg.value, msg.data);
    }

    /// @notice Requires a trusted transaction and non‑sanctioned msg.sender + addresses[]
    /// @param addresses An array of addresses that will be verified by the policy
    function requireTrustline(address[] memory addresses) internal {
        validationEngine.requireTrustline(msg.sender, msg.value, msg.data, addresses);
    }

    /// @notice Requires a trusted transaction and a non‑sanctioned msg.sender
    function requireTrustline() internal {
        validationEngine.requireTrustline(msg.sender, msg.value, msg.data);
    }

    /// @dev Runtime conformance check via EIP-165 to ensure the candidate advertises IValidationEngine.
    /// @dev This does not cryptographically attest Trustline provenance, but prevents accidental misconfiguration.
    function _assertValidationEngine(address candidate) private view {
        require(
            IERC165(candidate).supportsInterface(type(IValidationEngine).interfaceId),
            "Invalid validation engine"
        );
    }
}
