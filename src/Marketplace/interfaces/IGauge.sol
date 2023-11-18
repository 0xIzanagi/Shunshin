// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

interface IGauge {
    function notifyRewardAmount(uint256 amount) external;
    function getReward(address account) external;
    function claimFees() external returns (uint256 claimed0, uint256 claimed1);
    function left() external view returns (uint256);
    function isForPair() external view returns (bool);
}
