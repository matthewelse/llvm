#include "llvm/CodeGen/MacroFusion.h"

#include "RISCVMacroFusion.h"
#include "RISCVSubtarget.h"

#define DEBUG_TYPE "rv_fusion"

using namespace llvm;

static bool is_ld(const MachineInstr *instr) {
    switch (instr->getOpcode()) {
    case RISCV::LD:
    case RISCV::LW:
    case RISCV::LB:
    case RISCV::LBU:
    case RISCV::LH:
    case RISCV::LHU:
        return true;
    }

    return false;
}

static bool is_slli(const MachineInstr *instr) {
    switch (instr->getOpcode()) {
    case RISCV::SLLI:
    case RISCV::SLLIW:
        return true;
    }

    return false;
}

static bool is_srli(const MachineInstr *instr) {
    switch (instr->getOpcode()) {
    case RISCV::SRLI:
    case RISCV::SRLIW:
        return true;
    }

    return false;
}

static bool is_add(const MachineInstr *instr) {
    switch (instr->getOpcode()) {
    case RISCV::ADD:
    case RISCV::ADDW:
    case RISCV::ADDI:
    case RISCV::ADDIW:
        return true;
    }

    return false;
}

static bool shouldScheduleAdjacent(const TargetInstrInfo &tii, const TargetSubtargetInfo &tsi, const MachineInstr *instr1, const MachineInstr &instr2) {
    const RISCVSubtarget &subtarget = static_cast<const RISCVSubtarget &>(tsi);
    bool is_lea = false, is_ix_ld = false, is_cuw = false;

    if (!subtarget.hasMacroFusion()) {
        LLVM_DEBUG(dbgs() << "Not using macro fusion because subtarget does not have support.");
        return false;
    } else {
        LLVM_DEBUG(dbgs() << "Using macro fusion.");
    }

    is_lea = is_slli(instr1) && is_add(&instr2);
    is_ix_ld = is_add(instr1) && is_ld(&instr2);
    is_cuw = is_slli(instr1) && is_srli(&instr2);

    return is_lea || is_ix_ld || is_cuw;
}

namespace llvm {

std::unique_ptr<ScheduleDAGMutation> createRISCVMacroFusionDAGMutation () {
  return createMacroFusionDAGMutation(shouldScheduleAdjacent);
}

} // end namespace llvm

