// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {SimpleAA} from "../src/ethereum/SimpleAA.sol";
import {DevOpsTools} from "@foundry-devops/src/DevOpsTools.sol";

contract FundSimpleAA is Script {
    //script for funding simpleAA
    function run() external returns (string memory) {
        //change eth value to your heart's content
        SimpleAA simpleAA = SimpleAA(payable(DevOpsTools.get_most_recent_deployment("SimpleAA", block.chainid)));
        uint256 ethValue = 1000e18;
        return fund(ethValue);
    }

    function fund(uint256 ethValue) public returns (string memory) {
        vm.startBroadcast(msg.sender);
        (bool success,) = address(simpleAA).call{value: ethValue}("");
        vm.stopBroadcast();

        return ("SimpleAA funded");
    }
}
