pub const OperationName = enum {
    mov,
};

pub const Register = enum {
    ax,
    al,
    ah,
    bx,
    bl,
    bh,
    cx,
    cl,
    ch,
    dx,
    dl,
    dh,
    sp,
    bp,
    si,
    di,
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
