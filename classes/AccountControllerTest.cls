@isTest
public class AccountControllerTest {
    @isTest
    public static void verifyGetAccount(){
        List<Account> accList = new List<Account>();
        for(Integer i=0;i<10;i++){
            accList.add(new Account(Name='Testing'));
        }
        insert accList;
        List<Account>accList1 = new AccountController().getAccountByName('Testing');
        System.assertEquals(10, accList1.size(), 'expected 10 but foiund '+accList1.size());
    }

}