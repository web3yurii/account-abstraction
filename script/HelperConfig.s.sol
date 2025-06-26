// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {EntryPoint} from "account-abstraction/core/EntryPoint.sol";
import {console} from "forge-std/console.sol";

contract HelperConfig is Script {
    error HelperConfig__InvalidChainId();

    struct NetworkConfig {
        address entryPoint;
        address account;
    }

    uint256 private constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 private constant ZKSYNC_SEPOLIA_CHAIN_ID = 300;
    uint256 private constant ARBITRUM_SEPOLIA_CHAIN_ID = 421614;
    uint256 private constant LOCAL_ANVIL_CHAIN_ID = 31337;
    address private constant BURNER_WALLET = 0x326794fBB97ed389B2b1F6eF39006CB08ED89046;
    //    address private constant FOUNDRY_DEFAULT_WALLET = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;
    address private constant ANVIL_DEFAULT_ACCOUNT = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    NetworkConfig public activeNetworkConfig;

    mapping(uint256 chainId => NetworkConfig) public networkConfigs;

    constructor() {
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getEthSepoliaConfig();
        networkConfigs[ZKSYNC_SEPOLIA_CHAIN_ID] = getZkSyncSepoliaConfig();
        networkConfigs[ARBITRUM_SEPOLIA_CHAIN_ID] = getArbitrumSepoliaConfig();
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    function getConfigByChainId(uint256 chainId) public returns (NetworkConfig memory) {
        console.log("Chain ID:", chainId);
        if (chainId == LOCAL_ANVIL_CHAIN_ID) {
            return getLocalAnvilConfig();
        } else if (networkConfigs[chainId].entryPoint != address(0)) {
            return networkConfigs[chainId];
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }

    function getEthSepoliaConfig() internal pure returns (NetworkConfig memory) {
        return NetworkConfig({entryPoint: 0xB1ff3B2d5C8e4B6a7D9C3fD5a8E6B7F4C5D6E7F8, account: BURNER_WALLET});
    }

    function getZkSyncSepoliaConfig() internal pure returns (NetworkConfig memory) {
        return NetworkConfig({entryPoint: address(0), account: BURNER_WALLET});
    }

    function getArbitrumSepoliaConfig() internal returns (NetworkConfig memory) {
//        if (activeNetworkConfig.account != address(0)) {
//            console.log("Using cached Arbitrum Sepolia config");
//            return activeNetworkConfig;
//        }
//
//        console.log("Deploying new EntryPoint for Arbitrum Sepolia");
//
//        vm.startBroadcast();
//        EntryPoint entryPoint = new EntryPoint();
//        vm.stopBroadcast();

        activeNetworkConfig = NetworkConfig({entryPoint: address(0x0e5F4be5eCF942069365DC272e03881b542d9dd3), account: 0x326794fBB97ed389B2b1F6eF39006CB08ED89046});

        return activeNetworkConfig;
    }

    function getLocalAnvilConfig() internal returns (NetworkConfig memory) {
        if (activeNetworkConfig.account != address(0)) {
            return activeNetworkConfig;
        }

        vm.startBroadcast(ANVIL_DEFAULT_ACCOUNT);
        EntryPoint entryPoint = new EntryPoint();
        vm.stopBroadcast();

        activeNetworkConfig = NetworkConfig({entryPoint: address(entryPoint), account: ANVIL_DEFAULT_ACCOUNT});

        return activeNetworkConfig;
    }

    function run() external {}
}
