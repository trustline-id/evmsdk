// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/// @title Trustline's Validation interface
/// @author Trustline
/// @notice This interface defines the functions that must be implemented by the validation contract
/// @dev This interface is used by the Trustlined contract to interact with Trustline's Validation contract
/// @dev Implementations must override `supportsInterface` to advertise `type(IValidationEngine).interfaceId`
interface IValidationEngine is IERC165 {
    enum ValidationMode {
        Dapp,
        UniswapV4,
        MorphoV2,
        ERC3643
    }

    /// @notice Checks whether a transaction is trusted and verifies msg.sender + addresses[] against sanctions lists (advanced)
    /// @dev This call is required only in complex scenarios
    /// @dev WARNING: Improper use of this call may introduce security vulnerabilities in the calling contract
    /// @param mode The validation mode
    /// @param sender The transaction sender
    /// @param value Transaction value in wei
    /// @param data Transaction payload data
    /// @param addresses An array of addresses that will be verified by the policy
    function checkTrustlineStatus(
        ValidationMode mode,
        address sender,
        uint256 value,
        bytes calldata data,
        address[] memory addresses
    ) external view returns (bool);

    /// @notice Checks whether a transaction is trusted and verifies msg.sender + addresses[] against sanctions lists
    /// @param sender The transaction sender
    /// @param value Transaction value in wei
    /// @param data Transaction payload data
    /// @param addresses An array of addresses that will be verified by the policy
    function checkTrustlineStatus(
        address sender,
        uint256 value,
        bytes calldata data,
        address[] memory addresses
    ) external view returns (bool);

    /// @notice Checks whether a transaction is trusted and verifies msg.sender against sanctions lists
    /// @param sender The transaction sender
    /// @param value Transaction value in wei
    /// @param data Transaction payload data
    function checkTrustlineStatus(
        address sender,
        uint256 value,
        bytes calldata data
    ) external view returns (bool);

    /// @notice Requires a trusted transaction and non‑sanctioned msg.sender + addresses[] (advanced)
    /// @dev This call is required only in complex scenarios
    /// @dev WARNING: Improper use of this call may introduce security vulnerabilities in the calling contract
    /// @param mode The validation mode
    /// @param sender The transaction sender
    /// @param value Transaction value in wei
    /// @param data Transaction payload data
    /// @param addresses An array of addresses that will be verified by the policy
    function requireTrustline(
        ValidationMode mode,
        address sender,
        uint256 value,
        bytes calldata data,
        address[] memory addresses
    ) external;

    /// @notice Requires a trusted transaction and non‑sanctioned msg.sender + addresses[]
    /// @dev reverts if the transaction is not compliant
    /// @param sender The transaction sender
    /// @param value Transaction value in wei
    /// @param data Transaction payload data
    /// @param addresses An array of addresses that will be verified by the policy
    function requireTrustline(
        address sender,
        uint256 value,
        bytes calldata data,
        address[] memory addresses
    ) external;

    /// @notice Requires a trusted transaction and a non‑sanctioned msg.sender
    /// @dev reverts if the transaction is not compliant
    /// @param sender The transaction sender
    /// @param value Transaction value in wei
    /// @param data Transaction payload data
    function requireTrustline(
        address sender,
        uint256 value,
        bytes calldata data
    ) external;
}
