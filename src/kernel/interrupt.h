//
// Created by dingrui on 8/21/26.
//

#pragma once

// 前向声明
struct pt_regs;

void init_interrupt();

void do_IRQ(struct pt_regs *regs, unsigned long nr);
