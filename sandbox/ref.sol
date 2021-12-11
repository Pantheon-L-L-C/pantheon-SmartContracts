interface IKongz {
	function balanceOG(address _user) external view returns(uint256);
}



contract YieldToken is ERC20("Banana", "BANANA") {
	using SafeMath for uint256;

	uint256 constant public BASE_RATE = 10 ether; 
	uint256 constant public INITIAL_ISSUANCE = 300 ether;
	// Tue Mar 18 2031 17:46:47 GMT+0000
	uint256 constant public END = 1931622407;

	mapping(address => uint256) public rewards;
	mapping(address => uint256) public lastUpdate;

	IKongz public  kongzContract;

	event RewardPaid(address indexed user, uint256 reward);

	constructor(address _kongz) public{
		kongzContract = IKongz(_kongz);
	}


	function min(uint256 a, uint256 b) internal pure returns (uint256) {
		return a < b ? a : b;
	}

	// called when minting many NFTs
	// updated_amount = (balanceOG(user) * base_rate * delta / 86400) + amount * initial rate
	function updateRewardOnMint(address _user, uint256 _amount) external {
		require(msg.sender == address(kongzContract), "Can't call this");
		uint256 time = min(block.timestamp, END);
		uint256 timerUser = lastUpdate[_user];
		if (timerUser > 0)
			rewards[_user] = rewards[_user] + (kongzContract.balanceOG(_user) * (BASE_RATE * ((time - (timerUser))))/ (86400) + (_amount * (INITIAL_ISSUANCE)));
		else 
			rewards[_user] = rewards[_user].add(_amount.mul(INITIAL_ISSUANCE));
		lastUpdate[_user] = time;
	}

	// called on transfers
	function updateReward(address _from, address _to, uint256 _tokenId) external {
		require(msg.sender == address(kongzContract));
		if (_tokenId < 1001) {
			uint256 time = min(block.timestamp, END);
			uint256 timerFrom = lastUpdate[_from];
			if (timerFrom > 0) // this skips ppl getting reward w/o having had any balance but balanceOG would fuck that anyway // 
				rewards[_from] += kongzContract.balanceOG(_from).mul(BASE_RATE.mul((time.sub(timerFrom)))).div(86400); // time and timer from will subtract to 0
			if (timerFrom != END)
				lastUpdate[_from] = time;
			lastUpdate[_from] = time;
			if (_to != address(0)) {
				uint256 timerTo = lastUpdate[_to];
				if (timerTo > 0)
					rewards[_to] += kongzContract.balanceOG(_to).mul(BASE_RATE.mul((time.sub(timerTo)))).div(86400);
				if (timerTo != END)
					lastUpdate[_to] = time;
				lastUpdate[_to] = time;
			}
		}
	}

	function getReward(address _to) external {
		require(msg.sender == address(kongzContract));
		uint256 reward = rewards[_to];
		if (reward > 0) {
			rewards[_to] = 0;
			_mint(_to, reward);
			emit RewardPaid(_to, reward);
		}
	}

	function burn(address _from, uint256 _amount) external {
		require(msg.sender == address(kongzContract));
		_burn(_from, _amount);
	}

	function getTotalClaimable(address _user) external view returns(uint256) {
		uint256 time = min(block.timestamp, END);
		uint256 pending = kongzContract.balanceOG(_user).mul(BASE_RATE.mul((time.sub(lastUpdate[_user])))).div(86400);
		return rewards[_user] + pending;
	}
}



contract Kongz is ERC721Namable, Ownable {
	using ECDSA for bytes32;

	struct Kong {
		uint256 genes;
		uint256 bornAt;
	}

	address public constant burn = address(0x000000000000000000000000000000000000dEaD);
	IERC1155 public constant OPENSEA_STORE = IERC1155(0x495f947276749Ce646f68AC8c248420045cb7b5e);
	address constant public SIGNER = address(0x5E5e683b687f509968D90Acd31ce6b8Cfa3d25E4);
	uint256 constant public BREED_PRICE = 600 ether;


	mapping(uint256 => Kong) public kongz;
	mapping(address => uint256) public balanceOG;
	uint256 public bebeCount;

	YieldToken public yieldToken;
	IBreedManager breedManager;

	// Events
	event KongIncubated (uint256 tokenId, uint256 matron, uint256 sire);
	event KongBorn(uint256 tokenId, uint256 genes);
	event KongAscended(uint256 tokenId, uint256 genes);

	constructor(string memory _name, string memory _symbol, string[] memory _names, uint256[] memory _ids) public ERC721Namable(_name, _symbol, _names, _ids) {
		_setBaseURI("https://kongz.herokuapp.com/api/metadata/");
		_mint(msg.sender, 1001);
		_mint(msg.sender, 1002);
		_mint(msg.sender, 1003);
		kongz[1001] = Kong(0, block.timestamp);
		kongz[1002] = Kong(0, block.timestamp);
		kongz[1003] = Kong(0, block.timestamp);
		emit KongIncubated(1001, 0, 0);
		emit KongIncubated(1002, 0, 0);
		emit KongIncubated(1003, 0, 0);
		bebeCount = 3;
	}

	function updateURI(string memory newURI) public onlyOwner {
		_setBaseURI(newURI);
	}

	function setBreedingManager(address _manager) external onlyOwner {
		breedManager = IBreedManager(_manager);
	}

	function setYieldToken(address _yield) external onlyOwner {
		yieldToken = YieldToken(_yield);
	}

	function changeNamePrice(uint256 _price) external onlyOwner {
		nameChangePrice = _price;
	}

	function isValidKong(uint256 _id) pure internal returns(bool) {
		// making sure the ID fits the opensea format:
		// first 20 bytes are the maker address
		// next 7 bytes are the nft ID
		// last 5 bytes the value associated to the ID, here will always be equal to 1
		// There will only be 1000 kongz, we can fix boundaries and remove 5 ids that dont match kongz
		if (_id >> 96 != 0x000000000000000000000000a2548e7ad6cee01eeb19d49bedb359aea3d8ad1d)
			return false;
		if (_id & 0x000000000000000000000000000000000000000000000000000000ffffffffff != 1)
			return false;
		uint256 id = (_id & 0x0000000000000000000000000000000000000000ffffffffffffff0000000000) >> 40;
		if (id > 1005 || id == 262 || id == 197 || id == 75 || id == 34 || id == 18 || id == 0)
			return false;
		return true;
	}

	function returnCorrectId(uint256 _id) pure internal returns(uint256) {
		_id = (_id & 0x0000000000000000000000000000000000000000ffffffffffffff0000000000) >> 40;
		if (_id > 262)
			return _id - 5;
		else if (_id > 197)
			return _id - 4;
        else if (_id > 75)
            return _id - 3;
        else if (_id > 34)
            return _id - 2;
        else if (_id > 18)
            return _id - 1;
		else
			return _id;
	}

	function ascend(uint256 _tokenId, uint256 _genes, bytes calldata _sig) external {
		require(isValidKong(_tokenId), "Not valid Kong");
		uint256 id = returnCorrectId(_tokenId);
		require(keccak256(abi.encodePacked(id, _genes)).toEthSignedMessageHash().recover(_sig) == SIGNER, "Sig not valid");
	
		kongz[id] = Kong(_genes, block.timestamp);
		_mint(msg.sender, id);
		OPENSEA_STORE.safeTransferFrom(msg.sender, burn, _tokenId, 1, "");
		yieldToken.updateRewardOnMint(msg.sender, 1);
		balanceOG[msg.sender]++;
		emit KongAscended(id, _genes);
	}

	function breed(uint256 _sire, uint256 _matron) external {
		require(ownerOf(_sire) == msg.sender && ownerOf(_matron) == msg.sender);
		require(breedManager.tryBreed(_sire, _matron));

		yieldToken.burn(msg.sender, BREED_PRICE);
		bebeCount++;
		uint256 id = 1000 + bebeCount;
		kongz[id] = Kong(0, block.timestamp);
		_mint(msg.sender, id);
		emit KongIncubated(id, _matron, _sire);
	}

	function evolve(uint256 _tokenId) external {
		require(ownerOf(_tokenId) == msg.sender);
		Kong storage kong = kongz[_tokenId];
		require(kong.genes == 0);

		uint256 genes = breedManager.tryEvolve(_tokenId);
		kong.genes = genes;
		emit KongBorn(_tokenId, genes);
	}

	function changeName(uint256 tokenId, string memory newName) public override {
		yieldToken.burn(msg.sender, nameChangePrice);
		super.changeName(tokenId, newName);
	}

	function changeBio(uint256 tokenId, string memory _bio) public override {
		yieldToken.burn(msg.sender, BIO_CHANGE_PRICE);
		super.changeBio(tokenId, _bio);
	}

	function getReward() external {
		yieldToken.updateReward(msg.sender, address(0), 0);
		yieldToken.getReward(msg.sender);
	}

	function transferFrom(address from, address to, uint256 tokenId) public override {
		yieldToken.updateReward(from, to, tokenId);
		if (tokenId < 1001)
		{
			balanceOG[from]--;
			balanceOG[to]++;
		}
		ERC721.transferFrom(from, to, tokenId);
	}

	function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory _data) public override {
		yieldToken.updateReward(from, to, tokenId);
		if (tokenId < 1001)
		{
			balanceOG[from]--;
			balanceOG[to]++;
		}
		ERC721.safeTransferFrom(from, to, tokenId, _data);
	}

	function onERC1155Received(address _operator, address _from, uint256 _id, uint256 _value, bytes calldata _data) external returns(bytes4) {
		require(msg.sender == address(OPENSEA_STORE), "WrappedKongz: not opensea asset");
		return Kongz.onERC1155Received.selector;
	}
}