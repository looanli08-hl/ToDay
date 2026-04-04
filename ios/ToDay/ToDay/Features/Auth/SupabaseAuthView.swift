import SwiftUI

struct SupabaseAuthView: View {
    @ObservedObject var authManager = SupabaseAuthManager.shared
    @State private var isRegistering = false
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer()

            // Logo
            VStack(spacing: AppSpacing.xs) {
                Text("ToDay")
                    .font(.system(size: 32, weight: .regular, design: .serif))
                    .foregroundStyle(AppColor.label)

                Text("登录以同步你的生活数据")
                    .font(AppFont.subheadline)
                    .foregroundStyle(AppColor.labelSecondary)
            }

            // Form
            VStack(spacing: AppSpacing.md) {
                if isRegistering {
                    TextField("你的名字", text: $displayName)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.name)
                }

                TextField("邮箱", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)

                SecureField("密码", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(isRegistering ? .newPassword : .password)

                if let error = errorMessage {
                    Text(error)
                        .font(AppFont.caption)
                        .foregroundStyle(.red)
                }

                Button {
                    Task { await handleSubmit() }
                } label: {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppSpacing.sm)
                    } else {
                        Text(isRegistering ? "注册" : "登录")
                            .font(AppFont.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppSpacing.sm)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColor.workout) // warm orange-brown
                .disabled(isLoading || email.isEmpty || password.isEmpty)
            }
            .padding(.horizontal, AppSpacing.xl)

            // Toggle login/register
            Button {
                isRegistering.toggle()
                errorMessage = nil
            } label: {
                Text(isRegistering ? "已有账户？登录" : "没有账户？注册")
                    .font(AppFont.subheadline)
                    .foregroundStyle(AppColor.labelSecondary)
            }

            // Skip button
            Button {
                UserDefaults.standard.set(true, forKey: "today.auth.skipped")
            } label: {
                Text("稍后再说")
                    .font(AppFont.caption)
                    .foregroundStyle(AppColor.labelTertiary)
            }

            Spacer()
        }
        .background(AppColor.background)
    }

    private func handleSubmit() async {
        isLoading = true
        errorMessage = nil

        do {
            if isRegistering {
                try await authManager.signUp(
                    email: email,
                    password: password,
                    displayName: displayName.isEmpty
                        ? email.components(separatedBy: "@").first ?? "用户"
                        : displayName
                )
            } else {
                try await authManager.signIn(email: email, password: password)
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
