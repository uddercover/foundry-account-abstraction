// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {DeploySimpleAA, HelperConfig} from "../../script/DeploySimpleAA.s.sol";
import {SimpleAA} from "../../src/ethereum/SimpleAA.sol";
import {IEntryPoint} from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {PackedUserOperation} from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {SendPackedUserOp} from "../../script/SendPackedUserOp.s.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract SimpleAATest is Test {
    using MessageHashUtils for bytes32;

    SimpleAA simpleAA;
    ERC20Mock usdc;
    SendPackedUserOp sendPackedUserOp;
    HelperConfig.NetworkConfig networkConfig;
    address entryPoint;
    address stranger = makeAddr("stranger");

    uint256 constant USDC_TRANSFER_AMOUNT = 40;
    uint256 constant USDC_MINT_AMOUNT = 100;

    function setUp() public {
        HelperConfig helperConfig;
        DeploySimpleAA deploy = new DeploySimpleAA();
        (simpleAA, helperConfig) = deploy.run();

        networkConfig = helperConfig.getActiveNetworkConfig();
        entryPoint = networkConfig.entryPoint;

        usdc = new ERC20Mock();
        usdc.mint(address(simpleAA), USDC_MINT_AMOUNT);
        sendPackedUserOp = new SendPackedUserOp();

        vm.deal(address(simpleAA), 10e18);
        vm.deal(stranger, 10e18);
    }

    function testRandomAddressCannotCallExecute() public {
        //Arrange
        bytes memory functionData = abi.encodeWithSelector(usdc.transfer.selector, stranger, 40);

        //Act/Assert
        vm.expectRevert();
        vm.prank(stranger);
        simpleAA.execute(address(usdc), 0, functionData);
    }

    function testOwnerCanCallExecute() public {
        //Arrange
        uint256 strangerBalanceBeforeTransfer = usdc.balanceOf(stranger);
        assertEq(strangerBalanceBeforeTransfer, 0);

        bytes memory functionData = abi.encodeWithSelector(usdc.transfer.selector, stranger, USDC_TRANSFER_AMOUNT);
        uint256 value = 0;

        //Act
        vm.prank(simpleAA.owner());
        simpleAA.execute(address(usdc), value, functionData);

        //Assert
        uint256 strangerBalanceAfterTransfer = usdc.balanceOf(stranger);
        assertEq(strangerBalanceAfterTransfer, USDC_TRANSFER_AMOUNT);
        assertEq(usdc.balanceOf(address(simpleAA)), (USDC_MINT_AMOUNT - USDC_TRANSFER_AMOUNT));
    }

    function testUserOpIsSignedAsExpected() public view {
        uint256 strangerBalanceBeforeTransfer = usdc.balanceOf(stranger);
        assertEq(strangerBalanceBeforeTransfer, 0);

        bytes memory functionData = abi.encodeWithSelector(usdc.transfer.selector, stranger, USDC_TRANSFER_AMOUNT);
        uint256 value = 0;

        bytes memory executeCallData = abi.encodeWithSelector(simpleAA.execute.selector, usdc, value, functionData);
        PackedUserOperation memory packedUserOp =
            sendPackedUserOp.generateSignedUserOperation(executeCallData, networkConfig, address(simpleAA));
        bytes32 packedUserOpHash = IEntryPoint(entryPoint).getUserOpHash(packedUserOp);

        //Act
        address actualSigner = ECDSA.recover(packedUserOpHash.toEthSignedMessageHash(), packedUserOp.signature);

        //Assert
        assertEq(actualSigner, simpleAA.owner());
    }

    function testEntryPointCanValidateUserOp() public {
        //make a userop
        //add it to a userop array
        //pass this array to entryPoint
        //entrypoint passes the userop to validateOp

        //Arrange
        uint256 strangerBalanceBeforeTransfer = usdc.balanceOf(stranger);
        assertEq(strangerBalanceBeforeTransfer, 0);

        bytes memory functionData = abi.encodeWithSelector(usdc.transfer.selector, stranger, USDC_TRANSFER_AMOUNT);
        uint256 value = 0;

        bytes memory executeCallData = abi.encodeWithSelector(simpleAA.execute.selector, usdc, value, functionData);
        PackedUserOperation memory packedUserOp =
            sendPackedUserOp.generateSignedUserOperation(executeCallData, networkConfig, address(simpleAA));
        bytes32 packedUserOpHash = IEntryPoint(entryPoint).getUserOpHash(packedUserOp);
        uint256 missingAccountFunds = 1e18;

        // Act
        vm.prank(entryPoint);
        uint256 validationData = simpleAA.validateUserOp(packedUserOp, packedUserOpHash, missingAccountFunds);
        //Assert
        assertEq(validationData, 0);
    }

    function testOnlyEntryPointCanValidateUserOp() public {
        //Arrange
        uint256 strangerBalanceBeforeTransfer = usdc.balanceOf(stranger);
        assertEq(strangerBalanceBeforeTransfer, 0);

        bytes memory functionData = abi.encodeWithSelector(usdc.transfer.selector, stranger, USDC_TRANSFER_AMOUNT);
        uint256 value = 0;

        bytes memory executeCallData = abi.encodeWithSelector(simpleAA.execute.selector, usdc, value, functionData);
        PackedUserOperation memory packedUserOp =
            sendPackedUserOp.generateSignedUserOperation(executeCallData, networkConfig, address(simpleAA));
        bytes32 packedUserOpHash = IEntryPoint(entryPoint).getUserOpHash(packedUserOp);
        uint256 missingAccountFunds = 1e18;

        // Act/Assert
        vm.expectRevert();
        simpleAA.validateUserOp(packedUserOp, packedUserOpHash, missingAccountFunds);
    }

    function testFullExpectedEntryPointFlow() public {
        //Arrange
        uint256 strangerBalanceBeforeTransfer = usdc.balanceOf(stranger);
        assertEq(strangerBalanceBeforeTransfer, 0);

        bytes memory functionData = abi.encodeWithSelector(usdc.transfer.selector, stranger, USDC_TRANSFER_AMOUNT);
        uint256 value = 0;

        bytes memory executeCallData = abi.encodeWithSelector(simpleAA.execute.selector, usdc, value, functionData);

        PackedUserOperation memory packedUserOp =
            sendPackedUserOp.generateSignedUserOperation(executeCallData, networkConfig, address(simpleAA));

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = packedUserOp;

        //Act
        vm.prank(stranger);
        IEntryPoint(entryPoint).handleOps(ops, payable(stranger));

        //Assert
        uint256 strangerBalanceAfterTransfer = usdc.balanceOf(stranger);
        assertEq(strangerBalanceAfterTransfer, USDC_TRANSFER_AMOUNT);
        assertEq(usdc.balanceOf(address(simpleAA)), (USDC_MINT_AMOUNT - USDC_TRANSFER_AMOUNT));
    }
}
