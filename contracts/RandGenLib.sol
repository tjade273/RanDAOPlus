library RandGenLib {

  uint constant seedLength = 10;
  uint constant revealLength = 90;

  enum Phase = {Seed,Reveal}

  struct Seed {
    bytes32 seed;
    mapping(bytes32 => uint) deposits;
    mapping(address => bytes32);
    
  }

  struct Round {
    bytes32[] seeds;
    mapping(bytes32 => bytes32[]) hashes; //Proposed hashes
    mapping(bytes32 => address[]) deposits;
    Phase phase;
    bytes32 result;
    uint difficulty;
    uint reward;
    //uint seedEnd;
    //uint revealEnd;
    uint seedLimit;
    uint seedNumber;
    bytes32 blockHash;
    mapping(address => uint) tickets;
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

    if(self.seedNumber >= self.seedLimit) self.phase = Phase.Reveal;
  }

  function reveal(Round self, bytes32 seed, bytes32 result){
    if(self.phase != Phase.Reveal) throw;

    if(self.blockHash == 0) self.blockHash = block.hash(block.number-1);

    if(!self.randSeeds[seed]) throw;




  }


}
