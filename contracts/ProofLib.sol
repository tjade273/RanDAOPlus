library ProofLib {

    struct Proof {
        address defender;
        address challenger;

        bytes32 lVal;
        bytes32 rVal;
        uint lIndex;
        uint rIndex;

        uint roundTime;
        uint lastRound;

        bytes32 currentVal;

        //TODO: Implement non-participation resilliancy
    }


    function newChallenge(Proof storage self, address _defender, address _challenger, bytes32 seed, bytes32 result, uint difficulty, uint time) {
        self.defender = _defender;
        self.challenger = _challenger;

        self.lVal = seed;
        self.rVal = result;

        self.lIndex = 0;
        self.rIndex = difficulty;

        self.roundTime = time;
        self.lastRound = block.number;


    }

    function challenge(Proof storage self, bool correct) {
        if (self.currentVal == 0 || msg.sender != self.challenger) throw;
        if (correct) {
            self.lIndex = (self.lIndex + self.rIndex) / 2;
            self.lVal = self.currentVal;
        } else {
            self.rIndex = (self.lIndex + self.rIndex) / 2;
            self.rVal = self.currentVal;
        }

        self.currentVal = 0;
    }

    function respond(Proof storage self, bytes32 hash) {
        if (self.currentVal != 0 || msg.sender != self.defender) throw;
        self.currentVal = hash;
    }

    function finalize(Proof storage self) returns(bool confirmed) { //returns true if challenge successfully disproves proposal

        if (self.rIndex - self.lIndex <= 3) {
            bytes32 hash = self.lVal;

            for (uint i; i < self.rIndex - self.lIndex; i++) {
                hash = sha3(hash);
            }

            if (hash == self.rVal) {
                return false;
            } else {
                return true;
            }
        } else throw;
    }

    /*
     function getProof(uint id) constant returns(uint,uint,bytes32,bytes32,bytes32){
         return (proofs[id].lIndex,proofs[id].rIndex,proofs[id].lVal,proofs[id].currentVal, proofs[id].rVal);
     }

     function sha(bytes32 seed) constant returns(bytes32){
         return sha3(seed);
     }
    */
}
