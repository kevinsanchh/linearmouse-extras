// MIT License
// Copyright (c) 2021-2024 LinearMouse

import SwiftUI

struct PointerSettings: View {
    @ObservedObject var state = PointerSettingsState.shared

    var body: some View {
        DetailView {
            Form {
                if !state.customAccelerationEnabled {
                    Section {
                        HStack(spacing: 15) {
                            Toggle(isOn: $state.pointerDisableAcceleration.animation()) {
                                Text("Disable pointer acceleration")
                            }
                            .disabled(state.customAccelerationEnabled)

                            HelpButton {
                                NSWorkspace.shared
                                    .open(URL(string: "https://go.linearmouse.app/disable-pointer-acceleration-and-speed")!)
                            }
                        }

                        if !state.pointerDisableAcceleration {
                            HStack(alignment: .firstTextBaseline) {
                                Slider(value: $state.pointerAcceleration,
                                       in: 0.0 ... 20.0) {
                                    labelWithDescription {
                                        Text("Pointer acceleration")
                                        Text("(0–20)")
                                    }
                                }
                                TextField("",
                                          value: $state.pointerAcceleration,
                                          formatter: state.pointerAccelerationFormatter)
                                    .labelsHidden()
                                    .textFieldStyle(.roundedBorder)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 80)
                            }

                            HStack(alignment: .firstTextBaseline) {
                                Slider(value: $state.pointerSpeed,
                                       in: 0.0 ... 1.0) {
                                    labelWithDescription {
                                        Text("Pointer speed")
                                        Text("(0–1)")
                                    }
                                }
                                TextField("",
                                          value: $state.pointerSpeed,
                                          formatter: state.pointerSpeedFormatter)
                                    .labelsHidden()
                                    .textFieldStyle(.roundedBorder)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 80)
                            }

                            if #available(macOS 11.0, *) {
                                Button("Revert to system defaults") {
                                    revertPointerSpeed()
                                }
                                .keyboardShortcut("z", modifiers: [.control, .command, .shift])

                                Text("You may also press ⌃⇧⌘Z to revert to system defaults.")
                                    .controlSize(.small)
                                    .foregroundColor(.secondary)
                            } else {
                                Button("Revert to system defaults") {
                                    revertPointerSpeed()
                                }
                            }
                        } else if #available(macOS 14, *) {
                            HStack(alignment: .firstTextBaseline) {
                                Slider(value: $state.pointerAcceleration,
                                       in: 0.0 ... 20.0) {
                                    labelWithDescription {
                                        Text("Tracking speed")
                                        Text("(0–20)")
                                    }
                                }
                                TextField("",
                                          value: $state.pointerAcceleration,
                                          formatter: state.pointerAccelerationFormatter)
                                    .labelsHidden()
                                    .textFieldStyle(.roundedBorder)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 80)
                            }

                            Button("Revert to system defaults") {
                                revertPointerSpeed()
                            }
                            .keyboardShortcut("z", modifiers: [.control, .command, .shift])

                            Text("You may also press ⌃⇧⌘Z to revert to system defaults.")
                                .controlSize(.small)
                                .foregroundColor(.secondary)
                        }
                    }
                    .modifier(SectionViewModifier())
                }

                Section {
                    Toggle(isOn: $state.customAccelerationEnabled.animation()) {
                        Text("Enable custom pointer acceleration")
                    }

                    if state.customAccelerationEnabled {
                        HStack(alignment: .firstTextBaseline) {
                            Slider(value: $state.customAccelerationSensitivity, in: 0.0 ... 10.0) {
                                Text("Sensitivity")
                            }
                            TextField("",
                                      value: $state.customAccelerationSensitivity,
                                      formatter: state.customAccelerationFormatter)
                                .labelsHidden()
                                .textFieldStyle(.roundedBorder)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                        }
                        HStack(alignment: .firstTextBaseline) {
                            Slider(value: $state.customAccelerationAccel, in: -1.0 ... 1.0) {
                                Text("Acceleration")
                            }
                            TextField("",
                                      value: $state.customAccelerationAccel,
                                      formatter: state.customAccelerationFormatter)
                                .labelsHidden()
                                .textFieldStyle(.roundedBorder)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                        }
                        HStack(alignment: .firstTextBaseline) {
                            Slider(value: $state.customAccelerationLimit, in: 1.0 ... 10.0) {
                                Text("Limit")
                            }
                            TextField("",
                                      value: $state.customAccelerationLimit,
                                      formatter: state.customAccelerationFormatter)
                                .labelsHidden()
                                .textFieldStyle(.roundedBorder)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                        }
                        HStack(alignment: .firstTextBaseline) {
                            Slider(value: $state.customAccelerationDecay, in: 0.0 ... 10.0) {
                                Text("Decay rate")
                            }
                            TextField("",
                                      value: $state.customAccelerationDecay,
                                      formatter: state.customAccelerationFormatter)
                                .labelsHidden()
                                .textFieldStyle(.roundedBorder)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                        }
                        Button("Revert to Windows-like defaults") {
                            state.customAccelerationAccel = 0.04
                            state.customAccelerationLimit = 2
                            state.customAccelerationDecay = 2
                            state.customAccelerationSensitivity = 1
                        }
                    }
                }
                .modifier(SectionViewModifier())
            }
            .modifier(FormViewModifier())
        }
    }

    private func revertPointerSpeed() {
        state.revertPointerSpeed()
    }
}
