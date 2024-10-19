// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {EntryPoint} from "@account-abstraction/contracts/core/EntryPoint.sol";

contract HelperConfig is Script {
    uint256 constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 constant ZKSYNC_SEPOLIA_CHAIN_ID = 300;

    //change the addresses
    address sepoliaOwner = address(0);
    address zkSyncOwner = address(0);
    address anvilOwner = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address sepoliaEntryPoint = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;

    struct NetworkConfig {
        address owner;
        address entryPoint;
    }

    NetworkConfig activeNetworkConfig;

    constructor() {
        setActiveNetworkConfig();
    }

    function setActiveNetworkConfig() internal {
        if (block.chainid == ETH_SEPOLIA_CHAIN_ID) {
            activeNetworkConfig = getSepoliaEthNetworkConfig();
        } else if (block.chainid == ZKSYNC_SEPOLIA_CHAIN_ID) {
            activeNetworkConfig = getZkSyncSepoliaNetworkConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilNetworkConfig();
        }
    }

    function getSepoliaEthNetworkConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({owner: sepoliaOwner, entryPoint: sepoliaEntryPoint});
    }

    function getZkSyncSepoliaNetworkConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            owner: zkSyncOwner,
            entryPoint: address(0) // There is no entryPoint in zkSync!
        });
    }

    function getOrCreateAnvilNetworkConfig() public returns (NetworkConfig memory) {
        if (activeNetworkConfig.entryPoint != address(0)) {
            return activeNetworkConfig;
        }

        console2.log("Deploying mocks...");
        vm.startBroadcast(anvilOwner);
        EntryPoint mockEntryPoint = new EntryPoint();
        vm.stopBroadcast();

        return NetworkConfig({owner: anvilOwner, entryPoint: address(mockEntryPoint)});
    }

    function getActiveNetworkConfig() public view returns (NetworkConfig memory) {
        return activeNetworkConfig;
    }
}
