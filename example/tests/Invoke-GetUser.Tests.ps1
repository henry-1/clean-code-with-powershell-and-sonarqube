
Describe 'Invoke-GetUser'{

    It 'Get-ADuser_returns_user_samaccountname'{

        # Arrange
        Import-Module "./modules/ExampleModule.psm1" -Force

        # Act
        $user = Get-User -AccountName "Henry"

        # Assert
        $user.sAMaccountName | Should -Be "Henry"
    }
}