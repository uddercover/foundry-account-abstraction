// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {SimpleAA} from "../src/ethereum/SimpleAA.sol";

contract DeploySimpleAA is Script {
    HelperConfig config = new HelperConfig();

    function run() external returns (SimpleAA, HelperConfig) {
        HelperConfig.NetworkConfig memory networkConfig = config.getActiveNetworkConfig();
        address owner = networkConfig.owner;
        address entryPoint = networkConfig.entryPoint;

        return deploy(owner, entryPoint);
    }

    function deploy(address owner, address entryPoint) public returns (SimpleAA, HelperConfig) {
        vm.startBroadcast();
        SimpleAA simpleAA = new SimpleAA(owner, entryPoint);
        vm.stopBroadcast();

        return (simpleAA, config);
    }
}
