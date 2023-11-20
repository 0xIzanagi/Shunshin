// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IVoter {
    function emergencyCouncil() external view returns (address);
    function isWhitelisted(address token) external view returns (bool);
    function notifyRewardAmount(uint256 amount) external;
    function distribute(address _gauge) external;
    function isAlive(address) external view returns (bool);
}
