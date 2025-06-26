// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

import {IAccount} from "account-abstraction/interfaces/IAccount.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {SIG_VALIDATION_SUCCESS, SIG_VALIDATION_FAILED} from "account-abstraction/core/Helpers.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract MinimalAccount is IAccount, Ownable {
    /*//////////////////////////////////////////////////////////////
                           ERRORS
    //////////////////////////////////////////////////////////////*/
    error MinimalAccount__NotEntryPoint(address caller);
    error MinimalAccount__NotEntryPointOrOwner(address caller);
    error MinimalAccount__CallFailed(address dest, uint256 value, bytes data, bytes returnData);

    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    IEntryPoint private immutable i_entryPoint;

    /*//////////////////////////////////////////////////////////////
                           MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier onlyEntryPoint() {
        require(msg.sender == address(i_entryPoint), MinimalAccount__NotEntryPoint(msg.sender));
        _;
    }

    modifier onlyEntryPointOrOwner() {
        require(
            msg.sender == address(i_entryPoint) || msg.sender == owner(),
            MinimalAccount__NotEntryPointOrOwner(msg.sender)
        );
        _;
    }

    /*//////////////////////////////////////////////////////////////
                           FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    constructor(address entryPoint) Ownable(msg.sender) {
        i_entryPoint = IEntryPoint(entryPoint);
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function validateUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash, uint256 missingAccountFunds)
        external
        onlyEntryPoint
        returns (uint256 validationData)
    {
        validationData = _validateUserOp(userOp, userOpHash);
        // _validateNonce()
        _payPrefund(missingAccountFunds);
    }

    receive() external payable {}

    function execute(address dest, uint256 value, bytes calldata data) external onlyEntryPointOrOwner {
        (bool ok, bytes memory returnData) = dest.call{value: value}(data);
        require(ok, MinimalAccount__CallFailed(dest, value, data, returnData));
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    // EIP-191 signature validation
    function _validateUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash) internal view returns (uint256) {
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(userOpHash);
        address signer = ECDSA.recover(ethSignedMessageHash, userOp.signature);
        if (signer != owner()) {
            return SIG_VALIDATION_FAILED;
        }
        return SIG_VALIDATION_SUCCESS;
    }

    function _payPrefund(uint256 missingAccountFunds) internal {
        if (missingAccountFunds != 0) {
            // Logic to pay the prefund, e.g., transferring funds from the owner
            (bool ok, bytes memory data) = msg.sender.call{value: missingAccountFunds}("");
            if (!ok) {
                revert MinimalAccount__CallFailed(msg.sender, missingAccountFunds, "", data);
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                           GETTERS
    //////////////////////////////////////////////////////////////*/
    function getEntryPoint() external view returns (IEntryPoint) {
        return i_entryPoint;
    }
}
