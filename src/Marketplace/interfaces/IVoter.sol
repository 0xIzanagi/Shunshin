// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IVoter {
    function emergencyCouncil() external view returns (address);
    function attachTokenToGauge(address _sender, address account) external;
    function detachTokenFromGauge(uint _tokenId, address account) external;
    function emitDeposit(uint _tokenId, address account, uint amount) external;
    function emitWithdraw(uint _tokenId, address account, uint amount) external;
    function isWhitelisted(address token) external view returns (bool);
    function notifyRewardAmount(uint amount) external;
    function distribute(address _gauge) external;
    function isAlive(address) external view returns(bool);
}
