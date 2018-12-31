pragma solidity ^0.5.0;

interface RowingExternalSettingInterface {
    function getFastGap() external returns(uint256);
    function getLongGap() external returns(uint256);
    function getFastExtra() external returns(uint256);
    function getLongExtra() external returns(uint256);
}

