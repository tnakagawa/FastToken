// SPDX-License-Identifier: MIT
pragma solidity <0.9.0;

interface IChannel {
    // Open

    error FaildOpenChannel();

    event OpenChannel(address indexed channel, uint256 indexed index);

    struct OpenRequestData {
        address partner;
        uint256 total;
        uint256 amount1;
        uint256 amount2;
        uint256 deadline;
        bytes signature;
    }

    function open(OpenRequestData calldata request) external;

    // Close

    error FaildCloseChannel();

    event CloseChannel(address indexed channel, uint256 indexed index);

    struct CloseRequestData {
        address partner;
        uint256 amount1;
        uint256 amount2;
        uint256 deadline;
        bytes signature;
    }

    function close(CloseRequestData calldata request) external;

    // Hold

    error FaildHoldChannel();

    event HoldChannel(
        address indexed channel,
        uint256 indexed index,
        uint256 count,
        bytes32 preImage
    );

    struct HoldRequestData {
        address partner;
        uint256 amount1;
        uint256 amount2;
        uint256 count;
        uint256 lockterm;
        bytes32 preImage;
        bytes signature;
    }

    function hold(HoldRequestData calldata request) external;

    // Release

    error FaildRelease();

    event ReleaseChannel(address indexed channel, uint256 indexed index);

    function release(address partner) external;

    // Increase

    error FaildIncrease();

    event IncreaseChannel(address indexed channel, uint256 indexed index);

    struct IncreaseRequestData {
        address partner;
        uint256 amount1;
        uint256 amount2;
        uint256 deadline;
        bytes signature;
    }

    function increase(IncreaseRequestData calldata request) external;

    // Decrease

    error FaildDecrease();

    event DecreaseChannel(address indexed channel, uint256 indexed index);

    struct DecreaseRequestData {
        address partner;
        uint256 amount1;
        uint256 amount2;
        uint256 deadline;
        bytes signature;
    }

    function decrease(DecreaseRequestData calldata request) external;
}
