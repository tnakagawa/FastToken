// SPDX-License-Identifier: MIT
pragma solidity <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/Nonces.sol";
import "./IChannel.sol";

abstract contract Channel is IChannel, ERC20, EIP712, Nonces {
    // Channel Info Status
    uint8 internal constant _STATUS_NONE = 0;
    uint8 internal constant _STATUS_OPEN = 1;
    uint8 internal constant _STATUS_HOLD = 2;
    uint8 internal constant _STATUS_CLOSE = 3;

    struct ChannelInfo {
        uint8 status;
        uint256 index;
        uint256 amount1;
        uint256 amount2;
        uint256 count;
        uint256 locktime;
    }

    mapping(address channel => ChannelInfo) private _channelInfo;

    // ERC20 _update Error
    error ChannelAddress(address);

    // ERC20 _update override
    // Disable _update to channel
    function _update(
        address from,
        address to,
        uint256 value
    ) internal virtual override {
        if (_channelInfo[to].status != _STATUS_NONE) {
            revert ChannelAddress(to);
        }
        super._update(from, to, value);
    }

    function channelInfoOf(
        address channel
    ) public view virtual returns (ChannelInfo memory) {
        return _channelInfo[channel];
    }

    function channelIndexOf(
        address channel
    ) public view virtual returns (uint256) {
        return _channelInfo[channel].index;
    }

    error SameAddress(address);

    error InvalidPartner(address);

    function addressList(
        address partner
    )
        public
        view
        virtual
        returns (address channel, address address1, address address2)
    {
        if (partner == address(0)) {
            revert InvalidPartner(address(0));
        }
        if (partner == _msgSender()) {
            revert SameAddress(partner);
        }
        if (uint160(_msgSender()) < uint160(partner)) {
            address1 = _msgSender();
            address2 = partner;
        } else {
            address2 = _msgSender();
            address1 = partner;
        }
        channel = address(
            uint160(uint256(keccak256(abi.encodePacked(address1, address2))))
        );
    }

    function _recoverSigner(
        bytes memory data,
        bytes memory signature
    ) internal view virtual returns (bool, address) {
        bytes32 hash = _hashTypedDataV4(keccak256(data));
        (address recovered, ECDSA.RecoverError err, ) = ECDSA.tryRecover(
            hash,
            signature
        );
        return (err == ECDSA.RecoverError.NoError, recovered);
    }

    // Open

    bytes32 internal constant _OPEN_REQUEST_TYPEHASH =
        keccak256(
            "OpenRequest(address channel,uint256 index,uint256 total,uint256 amount1,uint256 amount2,uint256 nonce,uint256 deadline)"
        );

    function open(OpenRequestData calldata request) public virtual {
        if (!_open(request)) {
            revert FaildOpenChannel();
        }
    }

    function _open(
        OpenRequestData calldata request
    ) internal virtual returns (bool success) {
        (
            address channel,
            address address1,
            address address2,
            bool checkTotal,
            bool checkStatus,
            bool isActive,
            bool checkSign
        ) = _validateOpen(request);
        if (checkTotal && checkStatus && isActive && checkSign) {
            if (request.amount1 > 0) {
                _transfer(address1, channel, request.amount1);
            }
            if (request.amount2 > 0) {
                _transfer(address2, channel, request.amount2);
            }
            _channelInfo[channel].status = _STATUS_OPEN;
            _useNonce(request.partner);
            emit OpenChannel(channel, _channelInfo[channel].index);
            success = true;
        }
    }

    function _validateOpen(
        OpenRequestData calldata request
    )
        internal
        view
        virtual
        returns (
            address channel,
            address address1,
            address address2,
            bool checkTotal,
            bool checkStatus,
            bool isActive,
            bool checkSign
        )
    {
        (channel, address1, address2) = addressList(request.partner);
        checkTotal =
            request.total > 0 &&
            request.total ==
            balanceOf(channel) + request.amount1 + request.amount2;
        checkStatus =
            _channelInfo[channel].status == _STATUS_NONE ||
            _channelInfo[channel].status == _STATUS_CLOSE;
        isActive = request.deadline >= block.timestamp;
        (bool isValid, address recovered) = _recoverOpenRequestSigner(
            channel,
            request
        );
        checkSign = isValid && recovered == request.partner;
    }

    function _recoverOpenRequestSigner(
        address channel,
        OpenRequestData calldata request
    ) internal view virtual returns (bool isValid, address recovered) {
        (isValid, recovered) = _recoverSigner(
            abi.encode(
                _OPEN_REQUEST_TYPEHASH,
                channel,
                channelIndexOf(channel),
                request.total,
                request.amount1,
                request.amount2,
                nonces(request.partner),
                request.deadline
            ),
            request.signature
        );
    }

    function verifyOpen(
        OpenRequestData calldata request
    )
        public
        view
        virtual
        returns (
            address channel,
            address address1,
            address address2,
            bool checkTotal,
            bool checkStatus,
            bool isActive,
            bool checkSign
        )
    {
        (
            channel,
            address1,
            address2,
            checkTotal,
            checkStatus,
            isActive,
            checkSign
        ) = _validateOpen(request);
    }

    // Close

    bytes32 internal constant _CLOSE_REQUEST_TYPEHASH =
        keccak256(
            "CloseRequest(address channel,uint256 index,uint256 amount1,uint256 amount2,uint256 nonce,uint256 deadline)"
        );

    function close(CloseRequestData calldata request) public virtual {
        if (!_close(request)) {
            revert FaildCloseChannel();
        }
    }

    function _close(
        CloseRequestData calldata request
    ) internal virtual returns (bool success) {
        (
            address channel,
            address address1,
            address address2,
            bool checkTotal,
            bool checkStatus,
            bool isActive,
            bool checkSign
        ) = _validateClose(request);
        if (checkTotal && checkStatus && isActive && checkSign) {
            if (request.amount1 > 0) {
                _transfer(channel, address1, request.amount1);
            }
            if (request.amount2 > 0) {
                _transfer(channel, address2, request.amount2);
            }
            if (_channelInfo[channel].status == _STATUS_HOLD) {
                _channelInfo[channel].amount1 = 0;
                _channelInfo[channel].amount2 = 0;
                _channelInfo[channel].count = 0;
                _channelInfo[channel].locktime = 0;
            }
            _channelInfo[channel].status = _STATUS_CLOSE;
            _useNonce(request.partner);
            emit CloseChannel(channel, _channelInfo[channel].index);
            _channelInfo[channel].index++;
            success = true;
        }
    }

    function _validateClose(
        CloseRequestData calldata request
    )
        internal
        view
        virtual
        returns (
            address channel,
            address address1,
            address address2,
            bool checkTotal,
            bool checkStatus,
            bool isActive,
            bool checkSign
        )
    {
        (channel, address1, address2) = addressList(request.partner);
        checkTotal = balanceOf(channel) == request.amount1 + request.amount2;
        checkStatus =
            _channelInfo[channel].status == _STATUS_OPEN ||
            _channelInfo[channel].status == _STATUS_HOLD;
        isActive = request.deadline >= block.timestamp;
        (bool isValid, address recovered) = _recoverCloseRequestSigner(
            channel,
            request
        );
        checkSign = isValid && recovered == request.partner;
    }

    function _recoverCloseRequestSigner(
        address channel,
        CloseRequestData calldata request
    ) internal view virtual returns (bool isValid, address recovered) {
        (isValid, recovered) = _recoverSigner(
            abi.encode(
                _CLOSE_REQUEST_TYPEHASH,
                channel,
                channelIndexOf(channel),
                request.amount1,
                request.amount2,
                nonces(request.partner),
                request.deadline
            ),
            request.signature
        );
    }

    function verifyClose(
        CloseRequestData calldata request
    )
        public
        view
        returns (
            address channel,
            address address1,
            address address2,
            bool checkTotal,
            bool checkStatus,
            bool isActive,
            bool checkSign
        )
    {
        (
            channel,
            address1,
            address2,
            checkTotal,
            checkStatus,
            isActive,
            checkSign
        ) = _validateClose(request);
    }

    // Hold

    uint256 internal constant _MIN_LOCK_TERM = 0;

    uint256 internal constant _MAX_LOCK_TERM = 3600 * 24 * 21;

    bytes32 internal constant _HOLD_REQUEST_TYPEHASH =
        keccak256(
            "HoldRequest(address channel,uint256 index,uint256 amount1,uint256 amount2,uint256 count,uint256 lockterm,bytes32 payHash)"
        );

    function hold(HoldRequestData calldata request) public virtual {
        if (!_hold(request)) {
            revert FaildHoldChannel();
        }
    }

    function _hold(
        HoldRequestData calldata request
    ) internal virtual returns (bool success) {
        bytes32 payHash = keccak256(abi.encodePacked(request.preImage));
        (
            address channel,
            bool checkTotal,
            bool checkStatus,
            bool overCount,
            bool validLockTerm,
            bool checkSign
        ) = _validateHold(request, payHash);
        if (
            checkTotal && checkStatus && overCount && validLockTerm && checkSign
        ) {
            _channelInfo[channel].status = _STATUS_HOLD;
            _channelInfo[channel].amount1 = request.amount1;
            _channelInfo[channel].amount2 = request.amount2;
            _channelInfo[channel].count = request.count;
            _channelInfo[channel].locktime = block.timestamp + request.lockterm;
            emit HoldChannel(
                channel,
                _channelInfo[channel].index,
                _channelInfo[channel].count,
                request.preImage
            );
            success = true;
        }
    }

    function _validateHold(
        HoldRequestData calldata request,
        bytes32 payHash
    )
        internal
        view
        virtual
        returns (
            address channel,
            bool checkTotal,
            bool checkStatus,
            bool overCount,
            bool validLockTerm,
            bool checkSign
        )
    {
        (channel, , ) = addressList(request.partner);
        checkTotal = balanceOf(channel) == request.amount1 + request.amount2;
        checkStatus =
            _channelInfo[channel].status == _STATUS_OPEN ||
            _channelInfo[channel].status == _STATUS_HOLD;
        overCount = _channelInfo[channel].count < request.count;
        validLockTerm =
            _MIN_LOCK_TERM <= request.lockterm &&
            request.lockterm <= _MAX_LOCK_TERM;
        (bool isValid, address recovered) = _recoverHoldRequestSigner(
            channel,
            request,
            payHash
        );
        checkSign = isValid && recovered == request.partner;
    }

    function _recoverHoldRequestSigner(
        address channel,
        HoldRequestData calldata request,
        bytes32 payHash
    ) internal view virtual returns (bool, address) {
        return
            _recoverSigner(
                abi.encode(
                    _HOLD_REQUEST_TYPEHASH,
                    channel,
                    _channelInfo[channel].index,
                    request.amount1,
                    request.amount2,
                    request.count,
                    request.lockterm,
                    payHash
                ),
                request.signature
            );
    }

    function verifyHold(
        HoldRequestData calldata request
    )
        public
        view
        returns (
            address channel,
            bool checkTotal,
            bool checkStatus,
            bool overCount,
            bool validLockTerm,
            bool checkSign
        )
    {
        bytes32 payHash = keccak256(abi.encodePacked(request.preImage));
        (
            channel,
            checkTotal,
            checkStatus,
            overCount,
            validLockTerm,
            checkSign
        ) = _validateHold(request, payHash);
    }

    function verifyHoldOf(
        HoldRequestData calldata request,
        bytes32 payHash
    )
        public
        view
        returns (
            address channel,
            bool checkTotal,
            bool checkStatus,
            bool overCount,
            bool validLockTerm,
            bool checkSign
        )
    {
        (
            channel,
            checkTotal,
            checkStatus,
            overCount,
            validLockTerm,
            checkSign
        ) = _validateHold(request, payHash);
    }

    // Release

    function release(address partner) public {
        if (!_release(partner)) {
            revert FaildRelease();
        }
    }

    function _release(address partner) internal virtual returns (bool success) {
        (
            address channel,
            address address1,
            address address2,
            bool checkStatus,
            bool noLock
        ) = _validateRelease(partner);
        if (checkStatus && noLock) {
            if (_channelInfo[channel].amount1 > 0) {
                _transfer(channel, address1, _channelInfo[channel].amount1);
            }
            if (_channelInfo[channel].amount2 > 0) {
                _transfer(channel, address2, _channelInfo[channel].amount2);
            }
            emit ReleaseChannel(channel, channelIndexOf(channel));
            _channelInfo[channel].status = _STATUS_CLOSE;
            _channelInfo[channel].amount1 = 0;
            _channelInfo[channel].amount2 = 0;
            _channelInfo[channel].count = 0;
            _channelInfo[channel].locktime = 0;
            emit CloseChannel(channel, channelIndexOf(channel));
            _channelInfo[channel].index++;
            success = true;
        }
    }

    function _validateRelease(
        address partner
    )
        internal
        view
        virtual
        returns (
            address channel,
            address address1,
            address address2,
            bool checkStatus,
            bool noLock
        )
    {
        (channel, address1, address2) = addressList(partner);
        checkStatus = _channelInfo[channel].status == _STATUS_HOLD;
        noLock = _channelInfo[channel].locktime <= block.timestamp;
    }

    // Increase

    bytes32 internal constant _INCREASE_REQUEST_TYPEHASH =
        keccak256(
            "IncreaseRequest(address channel,uint256 index,uint256 amount1,uint256 amount2,uint256 nonce,uint256 deadline)"
        );

    function increase(IncreaseRequestData calldata request) public virtual {
        if (!_increase(request)) {
            revert FaildIncrease();
        }
    }

    function _increase(
        IncreaseRequestData calldata request
    ) internal virtual returns (bool success) {
        (
            address channel,
            address address1,
            address address2,
            bool checkStatus,
            bool isActive,
            bool checkSign
        ) = _validateIncrease(request);
        if (checkStatus && isActive && checkSign) {
            _channelInfo[channel].status = _STATUS_NONE;
            if (request.amount1 > 0) {
                _transfer(address1, channel, request.amount1);
            }
            if (request.amount2 > 0) {
                _transfer(address2, channel, request.amount2);
            }
            _channelInfo[channel].status = _STATUS_OPEN;
            _useNonce(request.partner);
            emit IncreaseChannel(channel, _channelInfo[channel].index);
            success = true;
        }
    }

    function _validateIncrease(
        IncreaseRequestData calldata request
    )
        internal
        view
        virtual
        returns (
            address channel,
            address address1,
            address address2,
            bool checkStatus,
            bool isActive,
            bool checkSign
        )
    {
        (channel, address1, address2) = addressList(request.partner);
        checkStatus = _channelInfo[channel].status == _STATUS_OPEN;
        isActive = request.deadline >= block.timestamp;
        (bool isValid, address recovered) = _recoverIncreaseRequestSigner(
            channel,
            request
        );
        checkSign = isValid && recovered == request.partner;
    }

    function _recoverIncreaseRequestSigner(
        address channel,
        IncreaseRequestData calldata request
    ) internal view virtual returns (bool isValid, address recovered) {
        (isValid, recovered) = _recoverSigner(
            abi.encode(
                _INCREASE_REQUEST_TYPEHASH,
                channel,
                _channelInfo[channel].index,
                request.amount1,
                request.amount2,
                nonces(request.partner),
                request.deadline
            ),
            request.signature
        );
    }

    function verifyIncrease(
        IncreaseRequestData calldata request
    )
        public
        view
        virtual
        returns (
            address channel,
            address address1,
            address address2,
            bool checkStatus,
            bool isActive,
            bool checkSign
        )
    {
        (
            channel,
            address1,
            address2,
            checkStatus,
            isActive,
            checkSign
        ) = _validateIncrease(request);
    }

    // Decrease

    bytes32 internal constant _DECREASE_REQUEST_TYPEHASH =
        keccak256(
            "DecreaseRequest(address channel,uint256 index,uint256 amount1,uint256 amount2,uint256 nonce,uint256 deadline)"
        );

    function decrease(DecreaseRequestData calldata request) public virtual {
        if (!_decrease(request)) {
            revert FaildDecrease();
        }
    }

    function _decrease(
        DecreaseRequestData calldata request
    ) internal virtual returns (bool success) {
        (
            address channel,
            address address1,
            address address2,
            bool checkTotal,
            bool checkStatus,
            bool isActive,
            bool checkSign
        ) = _validateDecrease(request);
        if (checkTotal && checkStatus && isActive && checkSign) {
            if (request.amount1 > 0) {
                _transfer(channel, address1, request.amount1);
            }
            if (request.amount2 > 0) {
                _transfer(channel, address2, request.amount2);
            }
            _useNonce(request.partner);
            emit DecreaseChannel(channel, _channelInfo[channel].index);
            success = true;
        }
    }

    function _validateDecrease(
        DecreaseRequestData calldata request
    )
        internal
        view
        virtual
        returns (
            address channel,
            address address1,
            address address2,
            bool checkTotal,
            bool checkStatus,
            bool isActive,
            bool checkSign
        )
    {
        (channel, address1, address2) = addressList(request.partner);
        checkTotal = balanceOf(channel) > (request.amount1 + request.amount2);
        checkStatus = _channelInfo[channel].status == _STATUS_OPEN;
        isActive = request.deadline >= block.timestamp;
        (bool isValid, address recovered) = _recoverDecreaseRequestSigner(
            channel,
            request
        );
        checkSign = isValid && recovered == request.partner;
    }

    function _recoverDecreaseRequestSigner(
        address channel,
        DecreaseRequestData calldata request
    ) internal view virtual returns (bool isValid, address recovered) {
        (isValid, recovered) = _recoverSigner(
            abi.encode(
                _DECREASE_REQUEST_TYPEHASH,
                channel,
                _channelInfo[channel].index,
                request.amount1,
                request.amount2,
                nonces(request.partner),
                request.deadline
            ),
            request.signature
        );
    }

    function verifyDecrease(
        DecreaseRequestData calldata request
    )
        public
        view
        returns (
            address channel,
            address address1,
            address address2,
            bool checktotal,
            bool checkStatus,
            bool isActive,
            bool checkSign
        )
    {
        (
            channel,
            address1,
            address2,
            checktotal,
            checkStatus,
            isActive,
            checkSign
        ) = _validateDecrease(request);
    }
}
