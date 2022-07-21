// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

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
    address public fallbackContract;

    /// @notice Emitted when the wallet's fallback contract is changed
    /// @param previous Previous fallback contract address
    /// @param current Current fallback contract address
    event FallbackContractChanged(
        address indexed previous,
        address indexed current
    );

    /// @notice Emitted when a fallback contract call is successfully made
    event FallbackContractCalled();

    /// @notice Emitted when the contract receives ether through receive()
    /// @param from Address that deposited ether into the wallet
    /// @param value Amount of wei deposited into the wallet
    event Deposit(address indexed from, uint256 value);

    /// @notice Sets the fallback contract address
    /// @dev Can only be called from the wallet itself
    function setFallbackContract(address _fallbackContract) public onlyWallet {
        fallbackContract = _fallbackContract;
    }

    /// @notice Makes a call to the fallback contract if it exists and
    ///     returns the result
    /// @dev The fallback contract must be set and it's required that the call
    ///     is successful
    fallback(bytes calldata callData) external payable returns (bytes memory) {
        if (fallbackContract == address(0)) return "";

        (bool success, bytes memory returnData) =
            fallbackContract.call{gas: gasleft(), value: msg.value}(callData);

        require(success);

        emit FallbackContractCalled();

        return returnData;
    }

    /// @notice Receives ether with no additional message data
    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }
}
