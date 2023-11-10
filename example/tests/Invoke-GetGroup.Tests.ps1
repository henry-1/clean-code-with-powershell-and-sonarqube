Describe 'Invoke-GetGroup'{

    It 'Get-ADuser_returns_user_samaccountname'{

        # Arrange
        Import-Module "./modules/ExampleModule.psm1" -Force

        # Act
        $group = Get-Group -AccountName "Group1"

        # Assert
        $group.sAMaccountName | Should -Be "Group1"
    }
}
