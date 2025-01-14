import SwiftUI
enum TextFieldType {
    case username
    case password
    case email
    case search
    case numeric
    case custom(placeholder: String, keyboardType: UIKeyboardType)
}

struct CustomTextField: View {
    @Binding var text: String
    var type: TextFieldType
    var maxLength: Int? = nil
    var borderColor: Color = AppColors.darkGray
    var borderWidth: CGFloat = 1
    var cornerRadius: CGFloat = 8
    var backgroundColor: Color = AppColors.white
    var showPasswordToggle: Bool = true
    var isEnabled: Bool = true
    @State private var isPasswordVisible: Bool = false

    var body: some View {
        ZStack(alignment: .trailing) {
            HStack {
                if case .search = type {
                    Image(systemName: "magnifyingglass").foregroundColor(.gray)
                }
                if case .password = type, !isPasswordVisible {
                    SecureField(placeholder, text: $text)
                        .textFieldStyle(PlainTextFieldStyle())
                        .keyboardType(keyboardType)
                        .disabled(!isEnabled)
                } else {
                    TextField(placeholder, text: $text)
                        .textFieldStyle(PlainTextFieldStyle())
                        .keyboardType(keyboardType)
                        .disabled(!isEnabled)
                }
            }
            .padding(8)
            .background(isEnabled ? backgroundColor : AppColors.lightGray)
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(isEnabled ? borderColor : AppColors.lightGray, lineWidth: borderWidth)
            )
            if case .password = type, showPasswordToggle, isEnabled {
                Button(action: { isPasswordVisible.toggle() }) {
                    Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                        .foregroundColor(.gray).padding(.trailing, 8)
                }
            }
        }
        .onChange(of: text) { newValue in
            if let maxLength = maxLength, newValue.count > maxLength {
                text = String(newValue.prefix(maxLength))
            }
        }
    }

    private var placeholder: String {
        switch type {
        case .username: return "Enter your username"
        case .password: return "Enter your password"
        case .email: return "Enter your email"
        case .search: return "Search"
        case .numeric: return "Enter a number"
        case .custom(let placeholder, _): return placeholder
        }
    }

    private var keyboardType: UIKeyboardType {
        switch type {
        case .username, .password, .email: return .default
        case .search: return .default
        case .numeric: return .numberPad
        case .custom(_, let keyboardType): return keyboardType
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        CustomTextField(text: .constant(""), type: .username)
        CustomTextField(text: .constant(""), type: .password, borderColor: .red, showPasswordToggle: true, isEnabled: false)
        CustomTextField(text: .constant(""), type: .email, borderColor: .green)
        CustomTextField(text: .constant(""), type: .search, borderColor: .gray, isEnabled: false)
        CustomTextField(text: .constant(""), type: .numeric, borderColor: .purple)
        CustomTextField(text: .constant(""), type: .custom(placeholder: "Enter custom input", keyboardType: .asciiCapable), borderColor: .orange)
    }
    .padding()
}
