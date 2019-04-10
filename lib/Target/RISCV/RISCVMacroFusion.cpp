#include "llvm/CodeGen/MacroFusion.h"

#include "RISCVMacroFusion.h"
#include "RISCVSubtarget.h"

#define DEBUG_TYPE "rv_fusion"

using namespace llvm;

static bool shouldScheduleAdjacent(const TargetInstrInfo &tii, const TargetSubtargetInfo &tsi, const MachineInstr *instr1, const MachineInstr &instr2) {
    const RISCVSubtarget &subtarget = static_cast<const RISCVSubtarget &>(tsi);
    bool is_lea = false, is_ix_ld = false, is_cuw = false;

    if (!subtarget.hasMacroFusion()) {
        LLVM_DEBUG(dbgs() << "Not using macro fusion because subtarget does not have support.");
        return false;
    } else {
        LLVM_DEBUG(dbgs() << "Using macro fusion.");
    }

    switch (instr2.getOpcode()) {
    case RISCV::LD:
    case RISCV::ADD:
    case RISCV::SRLI:
        // assume that null is a wildcard
        if (instr1 == nullptr)
            return true;

        is_lea = instr1->getOpcode() == RISCV::SLLI && instr2.getOpcode() == RISCV::ADD;
        is_ix_ld = instr1->getOpcode() == RISCV::ADD && instr2.getOpcode() == RISCV::LD;
        is_cuw = instr1->getOpcode() == RISCV::SLLI && instr2.getOpcode() == RISCV::SRLI;

        break;
    }

    return is_lea || is_ix_ld || is_cuw;
}

namespace llvm {

std::unique_ptr<ScheduleDAGMutation> createRISCVMacroFusionDAGMutation () {
  return createMacroFusionDAGMutation(shouldScheduleAdjacent);
}

} // end namespace llvm

