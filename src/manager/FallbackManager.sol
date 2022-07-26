// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "./MembershipManager.sol";

/// @title Multisig fallback contract management logic
/// @author Hyodar
/// @notice Adds the possibility of setting a fallback contract to a multisig
///     wallet through a vote.
/// @dev This fallback contract could be used to cover
///     cases in which there's the necessity of the multisig to be responding
///     to functions it wasn't designed for, increasing reusability. Inspired
///     by Gnosis Safe. Gnosis article on this: <https://help.gnosis-safe.io/en/articles/4738352-what-is-a-fallback-handler-and-how-does-it-relate-to-the-gnosis-safe>
abstract contract FallbackManager is MembershipManager {
    /// @notice Fallback contract that will be called when fallback() is triggered
    /// @custom:security write-protection="onlyWallet()"
    address public fallbackContract;

    /// @notice Emitted when the wallet's fallback contract is changed
    /// @param previous Previous fallback contract address
    /// @param current Current fallback contract address
    event FallbackContractChanged(
        address indexed previous,
        address indexed current
    );

    /// @notice Emitted when the contract receives ether through receive()
    /// @param from Address that deposited ether into the wallet
    /// @param value Amount of wei deposited into the wallet
    event Deposit(address indexed from, uint256 value);

    /// @notice Sets the fallback contract address
    /// @dev Can only be called from the wallet itself
    function setFallbackContract(address fallbackContract_)
        external
        onlyWallet
    {
        emit FallbackContractChanged(fallbackContract, fallbackContract_);
        // slither-disable-next-line missing-zero-check
        fallbackContract = fallbackContract_;
    }

    /// @notice Makes a call to the fallback contract if it exists and
    ///     returns the result
    /// @dev The fallback contract must be set and it's required that the call
    ///     is successful
    fallback(bytes calldata callData) external payable returns (bytes memory) {
        if (fallbackContract == address(0)) {
            if (msg.value != 0) {
                emit Deposit(msg.sender, msg.value);
            }

            return "";
        }

        // slither-disable-next-line low-level-calls
        (bool success, bytes memory returnData) =
            fallbackContract.call{gas: gasleft(), value: msg.value}(callData);

        require(success);

        return returnData;
    }

    /// @notice Receives ether with no additional message data
    receive() external payable {
        if (msg.value != 0) {
            emit Deposit(msg.sender, msg.value);
        }
    }
}
