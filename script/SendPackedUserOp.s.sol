// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {PackedUserOperation} from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {IEntryPoint} from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {DevOpsTools} from "@foundry-devops/src/DevOpsTools.sol";
import {Math} from "../src/ethereum/Math.sol";
import {SimpleAA} from "../src/ethereum/SimpleAA.sol";

contract SendPackedUserOp is Script {
    using MessageHashUtils for bytes32;

    function run() public {
        SimpleAA simpleAA = SimpleAA(payable(DevOpsTools.get_most_recent_deployment("SimpleAA", block.chainid)));
        address entryPoint = simpleAA.getEntryPoint();
        address simpleAAOwner = simpleAA.owner();
        address dest = DevOpsTools.get_most_recent_deployment("Math", block.chainid);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(Math.add.selector, 7, 8);
        bytes memory executeData = abi.encodeWithSelector(SimpleAA.execute.selector, dest, value, functionData);

        HelperConfig.NetworkConfig memory networkConfig =
            HelperConfig.NetworkConfig({owner: simpleAAOwner, entryPoint: entryPoint});

        PackedUserOperation memory userOp = generateSignedUserOperation(executeData, networkConfig, address(simpleAA));
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = userOp;

        vm.startBroadcast();
        IEntryPoint(entryPoint).handleOps(ops, payable(address(simpleAA)));
        vm.stopBroadcast();
    }

    function generateSignedUserOperation(
        bytes memory callData,
        HelperConfig.NetworkConfig memory networkConfig,
        address simpleAA
    ) public view returns (PackedUserOperation memory) {
        // Get entryPoint and owner from HelperConfig
        address entryPoint = networkConfig.entryPoint;
        address signer = networkConfig.owner;

        // Get unsigned userOp
        //vm.getNonce returns nonce plus 1 so I have to subtract 1
        uint256 nonce = vm.getNonce(simpleAA) - 1;
        PackedUserOperation memory userOp = _generateUnsignedUserOperation(callData, simpleAA, nonce);

        // Get userOpHash
        bytes32 unsignedUserOpHash = IEntryPoint(entryPoint).getUserOpHash(userOp);

        bytes32 digest = unsignedUserOpHash.toEthSignedMessageHash();

        // Sign and return userOp
        uint8 v;
        bytes32 r;
        bytes32 s;
        uint256 ANVIL_DEFAULT_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        if (block.chainid == 31337) {
            (v, r, s) = vm.sign(ANVIL_DEFAULT_KEY, digest);
        } else {
            (v, r, s) = vm.sign(signer, digest);
        }
        userOp.signature = abi.encodePacked(r, s, v);
        return userOp;
    }

    function _generateUnsignedUserOperation(bytes memory callData, address sender, uint256 nonce)
        internal
        pure
        returns (PackedUserOperation memory)
    {
        uint128 verificationGasLimit = 16777216;
        uint128 callGasLimit = verificationGasLimit;
        uint128 maxPriorityFeePerGas = 256;
        uint128 maxFeePerGas = maxPriorityFeePerGas;

        return PackedUserOperation({
            sender: sender,
            nonce: nonce,
            initCode: hex"",
            callData: callData,
            accountGasLimits: bytes32(uint256(verificationGasLimit) << 128 | callGasLimit),
            preVerificationGas: verificationGasLimit,
            gasFees: bytes32(uint256(maxPriorityFeePerGas) << 128 | maxFeePerGas),
            paymasterAndData: hex"",
            signature: hex""
        });
    }
}
