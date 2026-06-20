import SwiftUI

struct AddTaskView: View {
    @ObservedObject var vm: TaskViewModel
    @Environment(\.dismiss) var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var deadline = Date().addingTimeInterval(3600 * 24)

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.04, green: 0.06, blue: 0.04).ignoresSafeArea()

                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        label("FLIGHT NAME")
                        TextField("e.g. Project Report", text: $title)
                            .textFieldStyle(RadarTextFieldStyle())
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        label("MISSION BRIEF")
                        TextField("Task description...", text: $description, axis: .vertical)
                            .lineLimit(3...5)
                            .textFieldStyle(RadarTextFieldStyle())
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        label("SCHEDULED LANDING")
                        DatePicker("", selection: $deadline, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.compact)
                            .colorScheme(.dark)
                            .labelsHidden()
                    }

                    Spacer()

                    Button(action: submit) {
                        Text("FILE FLIGHT PLAN")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(title.isEmpty ? Color.green.opacity(0.4) : Color.green)
                            .cornerRadius(8)
                    }
                    .disabled(title.isEmpty)
                }
                .padding(20)
            }
            .navigationTitle("NEW FLIGHT PLAN")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("CANCEL") { dismiss() }
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.green)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundColor(.green.opacity(0.6))
    }

    private func submit() {
        let task = FlightTask(title: title, description: description, deadline: deadline)
        vm.addTask(task)
        dismiss()
    }
}

struct RadarTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.system(size: 14, design: .monospaced))
            .foregroundColor(.white)
            .padding(10)
            .background(Color.white.opacity(0.07))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.green.opacity(0.3), lineWidth: 1)
            )
    }
}
