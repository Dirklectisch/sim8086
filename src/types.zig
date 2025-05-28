pub const OperationName = enum {
    MOV,
};

pub const Register = enum {
    AX,
    AL,
    AH,
    BX,
    BL,
    BH,
    CX,
    CL,
    CH,
    DX,
    DL,
    DH,
    SP,
    BP,
    SI,
    DI,
};

pub const OperandType = enum {
    REGISTER,
};

pub const OperandRegister = struct {
    target: Register
};

pub const Operand = union(OperandType) {
    REGISTER: OperandRegister
};

pub const Instruction = struct {
    name: OperationName,
    destination: Operand,
    source: Operand
};
