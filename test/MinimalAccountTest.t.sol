// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {MinimalAccount} from "../src/MinimalAccount.sol";
import {DeployMinimalAccountScript} from "../script/DeployMinimalAccount.s.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {AccessManagedTarget} from "@openzeppelin/contracts/mocks/AccessManagedTarget.sol";
import {SendPackedUserOp} from "../script/SendPackedUserOp.s.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {console} from "forge-std/console.sol";

contract MinimalAccountTest is Test {
    using MessageHashUtils for bytes32;

    HelperConfig private helperConfig;
    MinimalAccount private minimalAccount;
    ERC20Mock private usdc;
    uint256 private constant AMOUNT = 1e18; // Local Anvil chain ID
    address private randomUser = makeAddr("randomUser");
    SendPackedUserOp private sendPackedUserOp;

    function setUp() public {
        DeployMinimalAccountScript deployMinimalAccount = new DeployMinimalAccountScript();
        (helperConfig, minimalAccount) = deployMinimalAccount.deployMinimalAccount();
        usdc = new ERC20Mock();
        sendPackedUserOp = new SendPackedUserOp();
    }

    function testCanExecuteCommand() public {
        // Arrange
        address account = address(minimalAccount);
        assertEq(usdc.balanceOf(account), 0, "Initial balance should be zero");
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory data = abi.encodeWithSelector(ERC20Mock.mint.selector, account, AMOUNT);
        // Act
        vm.prank(helperConfig.getConfig().account);
        minimalAccount.execute(dest, value, data);
        // Assert
        assertEq(usdc.balanceOf(account), AMOUNT, "Balance should be equal to AMOUNT after minting");
    }

    function testNonOwnerCanNotExecuteCommand() public {
        // Arrange
        address account = address(minimalAccount);
        assertEq(usdc.balanceOf(account), 0, "Initial balance should be zero");
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory data = abi.encodeWithSelector(ERC20Mock.mint.selector, account, AMOUNT);
        // Act
        vm.prank(randomUser);
        vm.expectRevert(
            abi.encodeWithSelector(MinimalAccount.MinimalAccount__NotEntryPointOrOwner.selector, randomUser)
        );
        minimalAccount.execute(dest, value, data);
    }

    function testRecoverSignedOp() public {
        // Arrange
        address account = address(minimalAccount);
        assertEq(usdc.balanceOf(account), 0, "Initial balance should be zero");
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory data = abi.encodeWithSelector(ERC20Mock.mint.selector, account, AMOUNT);
        bytes memory executeCallData = abi.encodeWithSelector(MinimalAccount.execute.selector, dest, value, data);
        PackedUserOperation memory userOp =
            sendPackedUserOp.generateSignedUserOperation(executeCallData, helperConfig.getConfig(), account);
        bytes32 userOpHash = IEntryPoint(helperConfig.getConfig().entryPoint).getUserOpHash(userOp);
        // Act
        address signer = ECDSA.recover(userOpHash.toEthSignedMessageHash(), userOp.signature);
        // Assert
        assertEq(signer, minimalAccount.owner(), "Signer should be the owner of the MinimalAccount");
    }

    function testValidateUserOp() public {
        // Arrange
        address account = address(minimalAccount);
        assertEq(usdc.balanceOf(account), 0, "Initial balance should be zero");
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory data = abi.encodeWithSelector(ERC20Mock.mint.selector, account, AMOUNT);
        bytes memory executeCallData = abi.encodeWithSelector(MinimalAccount.execute.selector, dest, value, data);
        PackedUserOperation memory userOp =
            sendPackedUserOp.generateSignedUserOperation(executeCallData, helperConfig.getConfig(), account);
        bytes32 userOpHash = IEntryPoint(helperConfig.getConfig().entryPoint).getUserOpHash(userOp);
        // Act
        vm.prank(helperConfig.getConfig().entryPoint);
        uint256 validationData = minimalAccount.validateUserOp(userOp, userOpHash, 0);
        // Assert
        console.log("Validation Data: %s", validationData);
        assertEq(validationData, 0);
    }

    function testEntryPointCanExecuteCommand() public {
        // Arrange
        address account = address(minimalAccount);
        assertEq(usdc.balanceOf(account), 0, "Initial balance should be zero");
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory data = abi.encodeWithSelector(ERC20Mock.mint.selector, account, AMOUNT);
        bytes memory executeCallData = abi.encodeWithSelector(MinimalAccount.execute.selector, dest, value, data);
        PackedUserOperation memory userOp =
            sendPackedUserOp.generateSignedUserOperation(executeCallData, helperConfig.getConfig(), account);
        vm.deal(account, AMOUNT);
        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = userOp;
        // Act
        vm.prank(randomUser);
        IEntryPoint(helperConfig.getConfig().entryPoint).handleOps(userOps, payable(randomUser));
        // Assert
        assertEq(usdc.balanceOf(account), AMOUNT, "Balance should be equal to AMOUNT after minting");
    }
}
