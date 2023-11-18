// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

interface IBribe {
    function _deposit(uint256 amount, address _owner) external;
    function _withdraw(uint256 amount, address _owner) external;
    function getRewardForOwner(address sender, address[] memory tokens) external;
    function notifyRewardAmount(address token, uint256 amount) external;
    function left(address token) external view returns (uint256);
}
