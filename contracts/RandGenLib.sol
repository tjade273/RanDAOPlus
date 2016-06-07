library RandGenLib {

  //uint constant seedLength = 10;
  //uint constant revealLength = 90;

  enum Phase = {Seed,Wait,Reveal}

  struct Seed {
    bytes32 seed;
    mapping(bytes32 => uint) hashDeposits;
    mapping(address => mapping(bytes32 => uint)) deposits;

  }

  struct Round {
    Seed[] seeds; // Initial seeds
    Phase phase;
    bytes32 result;
    uint difficulty;
    uint reward;
    //uint seedEnd;
    //uint revealEnd;
    uint seedLimit;
    uint seedNumber;
    uint blockHashNumber;
    bytes32 blockHash;
    mapping(address => uint) tickets;
    uint security;
  }

  function newRound(Round self, uint difficulty, uint reward){
    self.phase = Phase.Seed;
    self.difficulty =  difficulty;
    self.reward =  reward;
    //self.seedEnd = block.number + seedLength;
    //self.revealEnd = block.number + seedLength + revealLength;
  }

  function submitSeed(Round self, uint seed)  {
    if(self.phase != Phase.Seed) throw;

    self.randSeeds[sha3(seed,self.seedNumber)] = true;
    self.seedNumber++;

    if(self.seedNumber >= self.seedLimit) {
      self.blockHashNumber = block.number + 2;
      self.phase = Phase.Wait;
    }
  }

  function setBlockHash(Round self){
    if(self.phase != Phase.Wait) throw;
    if(self.blockHash == 0 && block.number > self.blockHashNumber) self.blockHash = block.hash(self.blockHashNumber);
  }

  function depositHash(Round self, bytes32 seed, bytes32 result, uint ammount){
    if(self.phase != Phase.Reveal) setBlockHash(self);
    if(!self.randSeeds[seed]) throw;

  }


}
