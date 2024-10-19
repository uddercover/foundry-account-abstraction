/**
 * Simulate:
 * A signing mechanism. Use it to sign a piece of data
 * Compile the data and the signature to form a userop
 * Send the userop to the entrypoint contract with the sender as the alt mempool
 * Call validate userop function in my contract from the entrypoint to validate the signature
 *   -The logic in this validate userop function should be capable of validating signatures from different signing mechanisms e.g google session keys, multisigs and regular priv keys
 *   - Check how exactly multisigs work and the google session key stuff
 * After validating the data, the entrypoint contract should call execute on my contract to execute a logic
 *
 *
 * Concerns: The main thing is the validation process. The execution logic depends entirely on the calldata specified in the userop. As long as I properly handle the calldata in my execute logic, I should be able to do anything on the blockchain.
 *
 * Questions: How do I perform a transfer on my EOA without using a wallet like metamask? Probably by using address.call{value: }
 *  How does the entrypoint contract know how to locate my account contract to call validate on
 */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAccount} from "@account-abstraction/contracts/interfaces/IAccount.sol";
import {IEntryPoint} from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {PackedUserOperation} from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SIG_VALIDATION_FAILED, SIG_VALIDATION_SUCCESS} from "@account-abstraction/contracts/core/Helpers.sol";

contract SimpleAA is IAccount, Ownable {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error SimpleAA__CallerMustBeEntryPoint();
    error SimpleAA__CallerMustBeEntryPointOrOwner();
    error SimpleAA__TransferFailed();
    error SimpleAA__CallFailed();

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    IEntryPoint private immutable i_entryPoint;

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier onlyEntryPoint() {
        if (msg.sender != address(i_entryPoint)) {
            revert SimpleAA__CallerMustBeEntryPoint();
        }
        _;
    }

    modifier onlyEntryPointOrOwner() {
        //if not either, revert
        if (msg.sender != owner() && msg.sender != address(i_entryPoint)) {
            revert SimpleAA__CallerMustBeEntryPointOrOwner();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    event SimpleAA__MissingAccountFundsPaid(bool);

    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    constructor(address _owner, address _entryPoint) Ownable(_owner) {
        i_entryPoint = IEntryPoint(_entryPoint);
    }

    receive() external payable {}

    function execute(address destination, uint256 value, bytes calldata functionData)
        external
        onlyEntryPointOrOwner
        returns (bytes memory)
    {
        (bool success, bytes memory data) = destination.call{value: value}(functionData);
        if (!success) {
            revert SimpleAA__CallFailed();
        }
        return data;
    }

    function validateUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash, uint256 missingAccountFunds)
        external
        onlyEntryPoint
        returns (uint256 validationData)
    {
        validationData = _validateUserOp(userOp, userOpHash);
        _payPrefund(missingAccountFunds);
    }

    function _validateUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash) internal view returns (uint256) {
        bytes memory signature = userOp.signature;
        bytes32 digest = userOpHash.toEthSignedMessageHash();
        (address signer,,) = digest.tryRecover(signature);

        if (signer == owner()) {
            return SIG_VALIDATION_SUCCESS;
        }
        return SIG_VALIDATION_FAILED;
    }

    //Contract would have to be funded to prevent this from failing
    function _payPrefund(uint256 missingAccountFunds) internal {
        if (missingAccountFunds != 0) {
            (bool success,) = payable(msg.sender).call{value: missingAccountFunds, gas: type(uint256).max}("");
            if (!success) {
                revert SimpleAA__TransferFailed();
            }

            emit SimpleAA__MissingAccountFundsPaid(success);
        }
    }

    /*//////////////////////////////////////////////////////////////
                                GETTERS
    //////////////////////////////////////////////////////////////*/
    function getEntryPoint() external view returns (address) {
        return address(i_entryPoint);
    }
}
