// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

interface IGauge {
    function notifyRewardAmount(uint amount) external;
    function getReward(address account) external;
    function claimFees() external returns (uint claimed0, uint claimed1);
    function left() external view returns (uint);
    function isForPair() external view returns (bool);
}
