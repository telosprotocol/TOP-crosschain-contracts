// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "../codec/EthProofDecoder.sol";
import "../../../lib/lib/EthereumDecoder.sol";
interface ITopProve {
    function verify(EthProofDecoder.Proof calldata proof, EthereumDecoder.TransactionReceiptTrie calldata receipt, EthereumDecoder.BlockHeader calldata header) external returns(bool valid, string memory reason);
}