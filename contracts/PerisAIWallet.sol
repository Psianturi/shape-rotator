// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract PerisAIWallet {
    address public userSigner;
    address public guardianSigner;
    uint256 public nonce;

    event TransferExecuted(address indexed to, uint256 amount, uint256 nonce);

    constructor(address _userSigner, address _guardianSigner) {
        userSigner = _userSigner;
        guardianSigner = _guardianSigner;
    }

    receive() external payable {}

    function executeTransfer(
        address payable to,
        uint256 amount,
        bytes calldata userSig,
        bytes calldata guardianSig
    ) external {
        bytes32 digest = getTransferDigest(to, amount, nonce);

        require(_recoverSigner(digest, userSig) == userSigner, "Invalid user signature");
        require(_recoverSigner(digest, guardianSig) == guardianSigner, "Invalid guardian signature");
        require(address(this).balance >= amount, "Insufficient contract balance");

        nonce += 1;
        (bool sent, ) = to.call{value: amount}("");
        require(sent, "Transfer failed");

        emit TransferExecuted(to, amount, nonce - 1);
    }

    function getTransferDigest(address to, uint256 amount, uint256 _nonce) public view returns (bytes32) {
        bytes32 messageHash = keccak256(abi.encodePacked(address(this), block.chainid, to, amount, _nonce));
        return _toEthSignedMessageHash(messageHash);
    }

    function _toEthSignedMessageHash(bytes32 messageHash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
    }

    function _recoverSigner(bytes32 digest, bytes calldata signature) internal pure returns (address) {
        require(signature.length == 65, "Invalid signature length");

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            r := calldataload(signature.offset)
            s := calldataload(add(signature.offset, 0x20))
            v := byte(0, calldataload(add(signature.offset, 0x40)))
        }

        if (v < 27) {
            v += 27;
        }
        require(v == 27 || v == 28, "Invalid signature version");

        return ecrecover(digest, v, r, s);
    }
}
