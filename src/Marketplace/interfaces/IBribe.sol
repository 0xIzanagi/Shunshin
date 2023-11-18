// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

interface IBribe {
    function _deposit(uint amount, address _owner) external;
    function _withdraw(uint amount, address _owner) external;
    function getRewardForOwner(address sender, address[] memory tokens) external;
    function notifyRewardAmount(address token, uint amount) external;
    function left(address token) external view returns (uint);
}
