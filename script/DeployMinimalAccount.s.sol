// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";

import {MinimalAccount} from "../src/MinimalAccount.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";

contract DeployMinimalAccountScript is Script {
    function run() external {
        (HelperConfig helperConfig, MinimalAccount minimalAccount) = deployMinimalAccount();
        console.log("MinimalAccount deployed at:", address(minimalAccount));
        console.log("HelperConfig deployed at:", address(helperConfig));
    }

    function deployMinimalAccount() public returns (HelperConfig, MinimalAccount) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        console.log("Deploying MinimalAccount with EntryPoint at:", config.entryPoint);

        vm.startBroadcast(config.account);
        MinimalAccount minimalAccount = new MinimalAccount(config.entryPoint);
        minimalAccount.transferOwnership(config.account);
        vm.stopBroadcast();

        console.log("MinimalAccount deployed at:", address(minimalAccount));
        return (helperConfig, minimalAccount);
    }
}
