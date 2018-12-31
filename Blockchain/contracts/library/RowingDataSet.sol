pragma solidity ^0.4.24;

library RowingDataSet {
    struct EventReturns {
        uint256 compressedData;
        uint256 compressedIDs;
        address winnerAddr;         // winner address
        bytes32 winnerName;         // winner name
        uint256 amountWon;          // amount won
        uint256 newPot;             // amount in new pot
        uint256 P3DAmount;          // amount distributed to p3d
        uint256 genAmount;          // amount distributed to gen
        uint256 potAmount;          // amount added to pot
    }
    struct Player {
        address addr;   // player address
        bytes32 name;   // player name
        uint256 win;    // winnings vault
        uint256 gen;    // general vault
        uint256 aff;    // affiliate vault
        uint256 lrnd;   // last round played
        uint256 laff;   // last affiliate id used
    }
    struct PlayerRounds {
        uint256 eth;    // eth player has added to round (used for eth limiter)
        uint256 keys;   // keys
        uint256 mask;   // player mask 
        uint256 ico;    // ICO phase investment
    }
    struct Round {
        uint256 plyr;   // pID of player in lead， 幸运儿
        uint256 team;   // tID of team in lead
        uint256 end;    // time ends/ended
        bool ended;     // has round end function been ran  这个开关值得研究下
        uint256 strt;   // time round started
        uint256 keys;   // keys
        uint256 eth;    // total eth in
        uint256 pot;    // eth to pot (during round) / final amount paid to winner (after round ends)
        uint256 mask;   // global mask
        uint256 ico;    // total eth sent in during ICO phase
        uint256 icoGen; // total eth for gen during ICO phase
        uint256 icoAvg; // average key price for ICO phase
    }
    
    struct TeamFee {
        uint256 gen;    // % of buy in thats paid to key holders of current round
        uint256 p3d;    // % of buy in thats paid to p3d holders
    }
    struct PotSplit {
        uint256 gen;    // % of pot thats paid to key holders of current round
        uint256 p3d;    // % of pot thats paid to p3d holders
    }
}