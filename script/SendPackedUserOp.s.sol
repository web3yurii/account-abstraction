// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MinimalAccount} from "../src/MinimalAccount.sol";

contract SendPackedUserOp is Script {
    using MessageHashUtils for bytes32;

    function run() external {
        HelperConfig helperConfig = new HelperConfig();
        address dest = 0xb1D4538B4571d411F07960EF2838Ce337FE1E80E;
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(IERC20.approve.selector, 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266, 1e18);
        bytes memory executionData = abi.encodeWithSelector(MinimalAccount.execute.selector, dest, value, functionData);
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        PackedUserOperation memory userOp = generateSignedUserOperation(
            executionData,
            config,
            0x7f8BC1DB222e823665f34dBad73198FDbba7Ce05
        );
        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = userOp;

        vm.startBroadcast();
        IEntryPoint(config.entryPoint).handleOps(userOps, payable(config.account));
        vm.stopBroadcast();
    }

    function generateSignedUserOperation(
        bytes memory callData,
        HelperConfig.NetworkConfig memory config,
        address account
    ) public view returns (PackedUserOperation memory) {
        uint256 nonce = vm.getNonce(account) - 1;
        PackedUserOperation memory userOp = generateUnsignedUserOp(callData, account, nonce);
        bytes32 userOpHash = IEntryPoint(config.entryPoint).getUserOpHash(userOp);
        bytes32 digest = userOpHash.toEthSignedMessageHash();

        uint8 v;
        bytes32 r;
        bytes32 s;
        uint256 ANVIL_DEFAULT_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        uint256 ARBITRUM_SEPOLIA_KEY = 0x0; // PK here (not recommended)
        if (block.chainid == 31337) {
            // Local Anvil chain ID
            (v, r, s) = vm.sign(ANVIL_DEFAULT_KEY, digest);
        } else if (block.chainid == 421614) {
            // Local Anvil chain ID
            (v, r, s) = vm.sign(ARBITRUM_SEPOLIA_KEY, digest);
        } else {
            // For other networks, use the configured account
            (v, r, s) = vm.sign(config.account, digest);
        }

        userOp.signature = abi.encodePacked(r, s, v); // Note the order of r, s, v
        return userOp;
    }

    function generateUnsignedUserOp(bytes memory callData, address sender, uint256 nonce)
        internal
        pure
        returns (PackedUserOperation memory)
    {
        uint128 verificationGasLimit = 16777216;
        uint128 callGasLimit = verificationGasLimit;
        uint256 maxPriorityFeePerGas = 256;
        uint256 maxFeePerGas = maxPriorityFeePerGas;

        return PackedUserOperation({
            sender: sender,
            nonce: nonce,
            initCode: new bytes(0),
            callData: callData,
            accountGasLimits: bytes32(uint256(verificationGasLimit) << 128 | uint256(callGasLimit)),
            preVerificationGas: verificationGasLimit,
            gasFees: bytes32(uint256(maxPriorityFeePerGas) << 128 | uint256(maxFeePerGas)),
            paymasterAndData: new bytes(0),
            signature: new bytes(0)
        });
    }
}
