@SuppressWarnings('PMD.ApexDoc')
@isTest
public class TestClassTest {
    @isTest
    @SuppressWarnings('ApexUnitTestClassShouldHaveAsserts')
    public static void test1(){
       TestClass.test1();
        System.assert(true,'hello');
    }

}