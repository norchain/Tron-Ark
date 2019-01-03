pragma solidity ^0.4.24;

import "./interface/otherRowing.sol";
import "./interface/FundForwarderInterface.sol";
import "./interface/PlayerBookInterface.sol";
import "./interface/HourglassInterface.sol";

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./library/UintCompressor.sol";
import "./library/NameFilter.sol";
import "./library/UintCompressor.sol";
import "./library/RowingKeysCalcLong.sol";
import "./library/RowingDataSet.sol";
import "./RowingEvents.sol";

import "./RowingModular.sol";

contract RowingMain is RowingModular {
    enum BoatName { RED, YELLOW, BLUE, GREEN }

    using SafeMath for *;
    using NameFilter for string;
    using RowingKeysCalcLong for uint256;

    // todo: replace address
    address constant private DEV_1_ADDRESS = 0x006B332340d355280B3F7aa2b33ea0AB0f5706E9;
	
    otherRowing private otherF3D_;
    // todo: replace address
    FundForwarderInterface constant private FundForwarder = FundForwarderInterface(0x884b2e7e1A722f03BcEa664852b33b4Eb715344e);
    PlayerBookInterface constant private PlayerBook = PlayerBookInterface(0x3e59be3531955757F69bF36a68Bc25D8D740ff3a);

    bool public activated_ = false;

    string constant public name = "Rowing";
    string constant public symbol = "NorchainRowing";
    uint256 private rndExtra_ =  10 minutes; //extSettings.getLongExtra();     // length of the very first ICO 
    uint256 private rndGap_ =   10 minutes; //extSettings.getLongGap();         // length of ICO phase, set to 1 year for EOS.
    uint256 constant private rndInit_ = 1 hours;                // round timer starts at this
    uint256 constant private rndInc_ = 30 seconds;              // every full key purchased adds this much to the timer
    uint256 constant private rndMax_ = 24 hours;                // max length a round timer can be

    uint256 constant public winningDistance = 24;        // if the fast boat distance is 10 bigger than the slowest boat

    uint256 public rID_;    // round id number / total rounds that have happened
    uint246 constant private initSpeed;

    // BOAT INFOMATION
    mapping (uint => uint256) boatSpeeds;
    mapping (uint => uint256) boatPositions;
    mapping (uint => uint256) boatPlayNumbers;
    mapping (uint => uint256) boatRuntimeSinceLastPositions;

    int256 public windSpeed;

    // PLAYER DATA 
    //****************
    mapping (address => uint256) public pIDxAddr_;          // (addr => pID) returns player id by address
    mapping (bytes32 => uint256) public pIDxName_;          // (name => pID) returns player id by name
    mapping (uint256 => RowingDataSet.Player) public plyr_;   // (pID => data) player data
    mapping (uint256 => mapping (uint256 => RowingDataSet.PlayerRounds)) public plyrRnds_;    // (pID => rID => data) player round data by player id & round id
    //一个用户可以有多个名字
    mapping (uint256 => mapping (bytes32 => bool)) public plyrNames_; // (pID => name => bool) list of names a player owns.  (used so you can change your display name amongst any name you own)
    //****************

    // ROUND DATA 
    //****************
    mapping (uint256 => RowingDataSet.Round) public round_;   // (rID => data) round data
    mapping (uint256 => mapping(uint256 => uint256)) public rndTmEth_;      // (rID => tID => data) eth in per team, by round id and team id
    // ****************
    // TEAM FEE DATA , Team的费用分配数据
    // ****************
    mapping (uint256 => RowingDataSet.TeamFee) public fees_;          // (team => fees) fee distribution by team
    mapping (uint256 => RowingDataSet.PotSplit) public potSplit_;     // (team => fees) pot split distribution by team

    constructor()
        public
    {
        //Team allocation structures
        // 0 = red boat
        // 1 = yellow boat
        // 2 = blue boat

        //     Referrals / Community rewards are mathematically designed to come from the winner's share of the pot.
        fees_[0] = RowingDataSet.TeamFee(36,0);   //50% to pot, 10% to aff, 2% to com, 1% to pot swap, 1% to air drop pot
        fees_[1] = RowingDataSet.TeamFee(43,0);   //43% to pot, 10% to aff, 2% to com, 1% to pot swap, 1% to air drop pot
        fees_[2] = RowingDataSet.TeamFee(66,0);  //20% to pot, 10% to aff, 2% to com, 1% to pot swap, 1% to air drop pot
        fees_[3] = RowingDataSet.TeamFee(51,0);   //35% to pot, 10% to aff, 2% to com, 1% to pot swap, 1% to air drop pot
        
        // how to split up the final pot based on which team was picked
        potSplit_[0] = RowingDataSet.PotSplit(25,0);  //48% to winner, 25% to next round, 2% to com
        potSplit_[1] = RowingDataSet.PotSplit(25,0);   //48% to winner, 25% to next round, 2% to com
        potSplit_[2] = RowingDataSet.PotSplit(40,0);  //48% to winner, 10% to next round, 2% to com
        potSplit_[3] = RowingDataSet.PotSplit(40,0);  //48% to winner, 10% to next round, 2% to com

        rID_ = 1;
        initSpeed = 10;
        windSpeed = 0;

        initGameMappings();


        if (msg.value == 0) {
            setBoatPlayerNumber(uint(BoatName.RED), 1);
        }

        if (msg.value == 1) {
            setBoatPlayerNumber(uint(BoatName.YELLOW), 1);
        }

        if (msg.value == 2) {
            setBoatPlayerNumber(uint(BoatName.BLUE), 1);
        }

        if (msg.value == 3) {
            setBoatPlayerNumber(uint(BoatName.GREEN), 1);
        }
        
    }

    /**
     * @dev used to make sure no one can interact with contract until it has 
     * been activated. 
     */
    modifier isActivated() {
        require(activated_ == true, "its not ready yet.  check ?eta in discord"); 
        _;
    }
    
    /**
     * @dev prevents contracts from interacting with fomo3d 
     */
    modifier isHuman() {
        address _addr = msg.sender;
        uint256 _codeLength;
        
        assembly {_codeLength := extcodesize(_addr)}
        require(_codeLength == 0, "sorry humans only");
        _;
    }

    /**
     * @dev sets boundaries for incoming tx 
     */
    modifier isWithinLimits(uint256 _eth) {
        require(_eth >= 1000000000, "pocket lint: not a valid currency");
        require(_eth <= 100000000000000000000000, "no vitalik, no");
        _;    
    }

    /**
     * @dev emergency buy uses last stored affiliate ID and team snek
     */
    function()
        isActivated()
        isHuman()
        isWithinLimits(msg.value)
        public
        payable
    {
        // set up our tx event data and determine if player is new or not
        RowingDataSet.EventReturns memory _eventData_ = determinePID(_eventData_);
            
        // fetch player id
        uint256 _pID = pIDxAddr_[msg.sender];

        // todo: 如果去为空怎么办？
        
        // buy core 
        buyCore(_pID, plyr_[_pID].laff, 2, _eventData_);
    }

    function initGameMappings()
        private
    {
        boatSpeeds[uint(BoatName.RED)] = 0;
        boatSpeeds[uint(BoatName.YELLOW)] = 0;
        boatSpeeds[uint(BoatName.BLUE)] = 0;
        boatSpeeds[uint(BoatName.GREEN)] = 0;

        boatPositions[uint(BoatName.RED)] = 0;
        boatPositions[uint(BoatName.YELLOW)] = 0;
        boatPositions[uint(BoatName.BLUE)] = 0;
        boatPositions[uint(BoatName.GREEN)] = 0;

        boatPlayNumbers[uint(BoatName.RED)] = 0;
        boatPlayNumbers[uint(BoatName.YELLOW)] = 0;
        boatPlayNumbers[uint(BoatName.BLUE)] = 0;
        boatPlayNumbers[uint(BoatName.GREEN)] = 0;

        boatRuntimeSinceLastPositions[uint(BoatName.RED)] = 0;
        boatRuntimeSinceLastPositions[uint(BoatName.YELLOW)] = 0;
        boatRuntimeSinceLastPositions[uint(BoatName.BLUE)] = 0;
        boatRuntimeSinceLastPositions[uint(BoatName.GREEN)] = 0;
    }

    // MARK: Helper functions getting and setting boats infos
    function getBoatSpeed(uint boatIndex) 
        private
        pure 
        returns (uint256)
    {
        require(uint(BoatName.GREEN) >= boatIndex && 0 <= boatIndex, "index should be valid");

        return boatSpeeds[boatIndex];
    }

    function setBoatSpeed(uint boatIndex, uint256 value)
        private
    {
        require(uint(BoatName.GREEN) >= boatIndex && 0 <= boatIndex, "index should be valid");

        boatSpeeds[boatIndex] = value;
    }

    function getBoatPosition(uint boatIndex) 
        private
        pure 
        returns (uint256)
    {
        require(uint(BoatName.GREEN) >= boatIndex && 0 <= boatIndex, "index should be valid");

        return boatPositions[boatIndex];
    }

    function setBoatPosition(uint boatIndex, uint256 value)
        private
    {
        require(uint(BoatName.GREEN) >= boatIndex && 0 <= boatIndex, "index should be valid");

        boatPositions[boatIndex] = value;
    }

    function getBoatPlayerNumber(uint boatIndex) 
        private
        pure 
        returns (uint256)
    {
        require(uint(BoatName.GREEN) >= boatIndex && 0 <= boatIndex, "index should be valid");

        return boatPlayNumbers[boatIndex];
    }

    function setBoatPlayerNumber(uint boatIndex, uint256 value)
        private
    {
        require(uint(BoatName.GREEN) >= boatIndex && 0 <= boatIndex, "index should be valid");

        boatPlayNumbers[boatIndex] = value;
    }

    function getBoatRuntimeSinceLastPositions(uint boatIndex) 
        private
        pure 
        returns (uint256)
    {
        require(uint(BoatName.GREEN) >= boatIndex && 0 <= boatIndex, "index should be valid");

        return boatRuntimeSinceLastPositions[boatIndex];
    }

    function setBoatRuntimeSinceLastPositions(uint boatIndex, uint256 value)
        private
    {
        require(uint(BoatName.GREEN) >= boatIndex && 0 <= boatIndex, "index should be valid");

        boatRuntimeSinceLastPositions[boatIndex] = value;
    }

    function joinBoat(uint boatNumber, uint256 playerID, bytes32 playerName, address playerAddress)
        isActivated()
        isHuman()
        public
    {
        require (msg.sender == address(PlayerBook), "your not playerNames contract... hmmm..");
        require(uint(BoatName.GREEN) >= boatNumber && 0 <= boatNumber, "index should be valid");
        // set up our tx event data and determine if player is new or not
        RowingDataSet.EventReturns memory _eventData_ = determinePID(_eventData_);
        
        // fetch player id
        uint256 _pID = pIDxAddr_[msg.sender];
        
        // manage affiliate residuals
        uint256 _affID;
        // if no affiliate code was given or player tried to use their own, lolz
        if (_affCode == address(0) || _affCode == msg.sender)
        {
            // use last stored affiliate code
            _affID = plyr_[_pID].laff;
        
        // if affiliate code was given    
        } else {
            // get affiliate ID from aff Code 
            _affID = pIDxAddr_[_affCode];
            
            // if affID is not the same as previously stored 
            if (_affID != plyr_[_pID].laff)
            {
                // update last affiliate
                plyr_[_pID].laff = _affID;
            }
        }

        if (_team == 0) {
            setBoatPlayerNumber(uint(BoatName.RED), 1 + getBoatPlayerNumber(uint(BoatName.RED)));
        }

        if (_team == 1) {
            setBoatPlayerNumber(uint(BoatName.YELLOW), 1 + getBoatPlayerNumber(uint(BoatName.YELLOW)));
        }

        if (_team == 2) {
            setBoatPlayerNumber(uint(BoatName.BLUE), 1 + getBoatPlayerNumber(uint(BoatName.BLUE)));
        }

        if (_team == 3) {
            setBoatPlayerNumber(uint(BoatName.GREEN), 1 + getBoatPlayerNumber(uint(BoatName.GREEN)));
        }

        if (pIDxAddr_[_addr] != _pID)
            pIDxAddr_[_addr] = _pID;
        if (pIDxName_[_name] != _pID)
            pIDxName_[_name] = _pID;
        if (plyr_[_pID].addr != _addr)
            plyr_[_pID].addr = _addr;
        if (plyr_[_pID].name != _name)
            plyr_[_pID].name = _name;
        if (plyr_[_pID].laff != _laff)
            plyr_[_pID].laff = _laff;
        if (plyrNames_[_pID][_name] == false)
            plyrNames_[_pID][_name] = true;

        updateBoatPositionAndSpeed();
    }


    function updateBoatPositionAndSpeed()
        isActivated()
        isHuman()
        public
    {
        // setup local rID 
        uint256 _rID = rID_;
        
        // grab time
        uint256 _now = now;

        uint256 redBoatNewPosition = getBoatPosition(uint(BoatName.RED)) + (now - getBoatRuntimeSinceLastPositions(uint(BoatName.RED))) * getBoatSpeed(uint(BoatName.RED));
        setBoatPosition(uint(BoatName.RED), redBoatNewPosition);

        uint256 yellowBoatNewPosition = getBoatPosition(uint(BoatName.YELLOW)) + (now - getBoatRuntimeSinceLastPositions(uint(BoatName.YELLOW))) * getBoatSpeed(uint(BoatName.YELLOW));
        setBoatPosition(uint(BoatName.YELLOW), yellowBoatNewPosition);

        uint256 blueBoatNewPosition = getBoatPosition(uint(BoatName.BLUE)) + (now - getBoatRuntimeSinceLastPositions(uint(BoatName.BLUE))) * getBoatSpeed(uint(BoatName.BLUE));
        setBoatPosition(uint(BoatName.BLUE), blueBoatNewPosition);

        uint256 greenBoatNewPosition = getBoatPosition(uint(BoatName.GREEN)) + (now - getBoatRuntimeSinceLastPositions(uint(BoatName.GREEN))) * getBoatSpeed(uint(BoatName.GREEN));
        setBoatPosition(uint(BoatName.GREEN), greenBoatNewPosition);

        setBoatRuntimeSinceLastPositions(uint(BoatName.RED), _now);
        setBoatRuntimeSinceLastPositions(uint(BoatName.YELLOW), _now);
        setBoatRuntimeSinceLastPositions(uint(BoatName.BLUE), _now);
        setBoatRuntimeSinceLastPositions(uint(BoatName.GREEN), _now);

        uint256 timeLeftForCurrentRound = getTimeLeft();
        if (timeLeftForCurrentRound == 0) {
            _rID += 1;
            rID_ += 1;
            bool isEnded = abs(redBoatNewPosition - yellowBoatNewPosition) > winningDistance 
                        || abs(redBoatNewPosition - blueBoatNewPosition) > winningDistance
                        || abs(redBoatNewPosition - greenBoatNewPosition) > winningDistance
                        || abs(yellowBoatNewPosition - blueBoatNewPosition) > winningDistance
                        || abs(yellowBoatNewPosition - greenBoatNewPosition) > winningDistance
                        || abs(blueBoatNewPosition - greenBoatNewPosition) > winningDistance;

            uint256 winnerBoatNumber = -1;
            if (isEnded) {
                winnerBoatNumber = findWinner();
            }
            emit RowingEvents.onEndRound
            (
                isEnded,
                _rID,
                winnerBoatNumber,
                redBoatNewPosition,
                yellowBoatNewPosition,
                blueBoatNewPosition,
                greenBoatNewPosition
            );
        }
    }

    function findWinner() 
        private
        returns (uint256)
    {
        uint256 winner;

        uint256 currentRedPosition = getBoatPosition(uint(BoatName.RED));
        uint256 currentYellowPosition = getBoatPosition(uint(BoatName.YELLOW));
        uint256 currentBluePosition = getBoatPosition(uint(BoatName.BLUE));
        uint256 currentGreenPosition = getBoatPosition(uint(BoatName.GREEN));
        uint256 fastestPosition = max(max(max(currentRedPosition, currentYellowPosition), currentBluePosition), currentGreenPosition);
        if (fastestPosition == currentRedPosition) {
            winner = 0;
        }
        if (fastestPosition == currentYellowPosition) {
            winner = 1;
        }
        if (fastestPosition == currentBluePosition) {
            winner = 2;
        }
        if (fastestPosition == currentGreenPosition) {
            winner = 2;
        }
        return winner;
    }

    /**
     * @dev gets existing or registers new pID.  use this when a player may be new
     * @return pID 
     */
    function determinePID(RowingDataSet.EventReturns memory _eventData_)
        private
        returns (RowingDataSet.EventReturns)
    {
        uint256 _pID = pIDxAddr_[msg.sender];
        // if player is new to this version of fomo3d
        if (_pID == 0)
        {
            // grab their player ID, name and last aff ID, from player names contract 
            _pID = PlayerBook.getPlayerID(msg.sender);
            bytes32 _name = PlayerBook.getPlayerName(_pID);
            uint256 _laff = PlayerBook.getPlayerLAff(_pID);
            
            // set up player account 
            pIDxAddr_[msg.sender] = _pID;
            plyr_[_pID].addr = msg.sender;
            
            if (_name != "")
            {
                pIDxName_[_name] = _pID;
                plyr_[_pID].name = _name;
                plyrNames_[_pID][_name] = true;
            }
            
            if (_laff != 0 && _laff != _pID)
                plyr_[_pID].laff = _laff;
            
            // set the new player bool to true
            _eventData_.compressedData = _eventData_.compressedData + 1;
        } 
        return (_eventData_);
    }

    /**
     * @dev returns time left.  dont spam this, you'll ddos yourself from your node 
     * provider
     * -functionhash- 0xc7e284b8
     * @return time left in seconds
     */
    function getTimeLeft()
        public
        view
        returns(uint256)
    {
        // setup local rID
        uint256 _rID = rID_;
        
        // grab time
        uint256 _now = now;
        
        if (_now < round_[_rID].end)
            if (_now > round_[_rID].strt + rndGap_)
                return( (round_[_rID].end).sub(_now) );
            else
                return( (round_[_rID].strt + rndGap_).sub(_now) );
        else
            return(0);
    }

    /**
     * @dev withdraws all of your earnings.
     * -functionhash- 0x3ccfd60b
     */
    function withdraw()
        isActivated()
        isHuman()
        public
    {
        // setup local rID 
        uint256 _rID = rID_;
        
        // grab time
        uint256 _now = now;
        
        // fetch player ID
        uint256 _pID = pIDxAddr_[msg.sender];
        
        // setup temp var for player eth
        uint256 _eth;
        
        // check to see if round has ended and no one has run round end yet
        if (_now > round_[_rID].end && round_[_rID].ended == false && round_[_rID].plyr != 0)
        {
            // set up our tx event data
            F3Ddatasets.EventReturns memory _eventData_;
            
            // end the round (distributes pot)
			round_[_rID].ended = true;
            _eventData_ = endRound(_eventData_);
            
			// get their earnings
            _eth = withdrawEarnings(_pID);
            
            // gib moni
            if (_eth > 0)
                plyr_[_pID].addr.transfer(_eth);    
            
            // build event data
            _eventData_.compressedData = _eventData_.compressedData + (_now * 1000000000000000000);
            _eventData_.compressedIDs = _eventData_.compressedIDs + _pID;
            
            // fire withdraw and distribute event
            emit RowingEvents.onWithdrawAndDistribute
            (
                msg.sender, 
                plyr_[_pID].name, 
                _eth, 
                _eventData_.compressedData, 
                _eventData_.compressedIDs, 
                _eventData_.winnerAddr, 
                _eventData_.winnerName, 
                _eventData_.amountWon, 
                _eventData_.newPot, 
                _eventData_.P3DAmount, 
                _eventData_.genAmount
            );
            
        // in any other situation
        } else {
            // get their earnings
            _eth = withdrawEarnings(_pID);
            
            // gib moni
            if (_eth > 0)
                plyr_[_pID].addr.transfer(_eth);
            
            // fire withdraw event
            emit RowingEvents.onWithdraw(_pID, msg.sender, plyr_[_pID].name, _eth, _now);
        }
    }

    /**
     * @dev checks to make sure user picked a valid team.  if not sets team 
     * to default (sneks)
     */
    function verifyTeam(uint256 _team)
        private
        pure
        returns (uint256)
    {
        if (_team < uint(BoatName.RED) || _team > uint(BoatName.GREEN))
            return(0);
        else
            return(_team);
    }

    /**
     * @dev converts all incoming ethereum or Tron to keys.
     * -functionhash- 0x8f38f309 (using ID for affiliate)
     * -functionhash- 0x98a0871d (using address for affiliate)
     * -functionhash- 0xa65b37a1 (using name for affiliate)
     * @param _affCode the ID/address/name of the player who gets the affiliate fee
     * @param _team what team is the player playing for?
     */
    function buyXid(uint256 _affCode, uint256 _team)
        isActivated()
        isHuman()
        isWithinLimits(msg.value)
        public
        payable
    {
        // set up our tx event data and determine if player is new or not
        RowingDataSet.EventReturns memory _eventData_ = determinePID(_eventData_);
        
        // fetch player id
        uint256 _pID = pIDxAddr_[msg.sender];
        
        // manage affiliate residuals
        // if no affiliate code was given or player tried to use their own, lolz
        if (_affCode == 0 || _affCode == _pID)
        {
            // use last stored affiliate code 
            _affCode = plyr_[_pID].laff;
            
        // if affiliate code was given & its not the same as previously stored 
        } else if (_affCode != plyr_[_pID].laff) {
            // update last affiliate 
            plyr_[_pID].laff = _affCode;
        }
        
        // verify a valid team was selected
        _team = verifyTeam(_team);
        
        // buy core 
        buyCore(_pID, _affCode, _team, _eventData_);
    }

    /**
     * @dev logic runs whenever a buy order is executed.  determines how to handle 
     * incoming eth depending on if we are in an active round or not
     */
    function buyCore(uint256 _pID, uint256 _affID, uint256 _team, F3Ddatasets.EventReturns memory _eventData_)
        private
    {
        // setup local rID
        uint256 _rID = rID_;
        
        // grab time
        uint256 _now = now;
        
        // if round is active
        if (_now > round_[_rID].strt + rndGap_ && (_now <= round_[_rID].end || (_now > round_[_rID].end && round_[_rID].plyr == 0))) 
        {
            // call core 
            core(_rID, _pID, msg.value, _affID, _team, _eventData_);
        
        // if round is not active     
        } else {
            // check to see if end round needs to be ran
            if (_now > round_[_rID].end && round_[_rID].ended == false) 
            {
                // end the round (distributes pot) & start new round
			    round_[_rID].ended = true;
                _eventData_ = endRound(_eventData_);
                
                // build event data
                _eventData_.compressedData = _eventData_.compressedData + (_now * 1000000000000000000);
                _eventData_.compressedIDs = _eventData_.compressedIDs + _pID;
                
                // fire buy and distribute event 
                emit RowingEvents.onBuyAndDistribute
                (
                    msg.sender, 
                    plyr_[_pID].name, 
                    msg.value, 
                    _eventData_.compressedData, 
                    _eventData_.compressedIDs, 
                    _eventData_.winnerAddr, 
                    _eventData_.winnerName, 
                    _eventData_.amountWon, 
                    _eventData_.newPot, 
                    _eventData_.P3DAmount, 
                    _eventData_.genAmount
                );
            }
            
            // put eth in players vault 
            plyr_[_pID].gen = plyr_[_pID].gen.add(msg.value);
        }
    }
}

