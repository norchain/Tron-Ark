pragma solidity ^0.4.24;

import "../../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

library RowingKeysCalcLong {
    using SafeMath for *;

    /**
     * @dev calculates number of keys received given X eth 
     * @param _curEth current amount of eth in contract 
     * @param _newEth eth being spent
     * @return amount of ticket purchased
     */
    function keysRec(uint256 _curEth, uint256 _newEth)
        internal
        pure
        returns (uint256)
    {
        return(keys((_curEth).add(_newEth)).sub(keys(_curEth)));
    }
    
    /**
     * @dev calculates amount of eth received if you sold X keys 
     * @param _curKeys current amount of keys that exist 
     * @param _sellKeys amount of keys you wish to sell
     * @return amount of eth received
     */
    function ethRec(uint256 _curKeys, uint256 _sellKeys)
        internal
        pure
        returns (uint256)
    {
        return((eth(_curKeys)).sub(eth(_curKeys.sub(_sellKeys))));
    }

    /**
     * @dev calculates how many keys would exist with given an amount of eth
     * @param _eth eth "in contract"
     * @return number of keys that would exist
     */
    function keys(uint256 _eth) 
        internal
        pure
        returns(uint256)
    {
        return ((sqrt((_eth).mul(1000000000000000000).mul(312500000000000000000000000)).add(5624988281256103515625000000000000000000000000000000000000000000))).sub(74999921875000000000000000000000) / (156250000);
    }
    
    /**
     * @dev calculates how much eth would be in contract given a number of keys
     * @param _keys number of keys "in contract" 
     * @return eth that would exists
     */
    function eth(uint256 _keys) 
        internal
        pure
        returns(uint256)  
    {
        return ((78125000).mul(sq(_keys)).add(((149999843750000).mul(_keys.mul(1000000000000000000))) / (2))) / (sq(1000000000000000000));
    }

    /**
     * @dev gives square. multiplies x by x
     */
    function sq(uint256 x)
        internal
        pure
        returns (uint256)
    {
        return (x.mul(x));
    }

    /**
     * @dev gives square root of given x.
     */
    function sqrt(uint256 x)
        internal
        pure
        returns (uint256 y) 
    {
        uint256 z = ((x.add(1)) / 2);
        y = x;
        while (z < y) 
        {
            y = z;
            z = (((x / z).add(z)) / 2);
        }
    }
}