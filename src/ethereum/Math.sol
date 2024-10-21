// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @dev This contract is a destination contract for testing simpleAA on anvil and other testnets
 * It must be deployed before sending a simpleAA userOp
 */
contract Math {
    function add(uint256 a, uint256 b) public pure returns (uint256) {
        return a + b;
    }

    function subtract(uint256 subtracted, uint256 subtractor) public pure returns (uint256) {
        return subtractor - subtracted;
    }

    receive() external payable {}
}
