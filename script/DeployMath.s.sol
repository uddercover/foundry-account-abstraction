// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {Math} from "../src/ethereum/Math.sol";

contract DeployMath is Script {
    function run() external returns (Math) {
        vm.startBroadcast();
        Math math = new Math();
        vm.stopBroadcast();
        return math;
    }
}
