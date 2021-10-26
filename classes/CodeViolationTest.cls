@isTest
public class CodeViolationTest {
	@isTest
    public static void verifycheckSCA(){
        Integer i = CodeViolation.checkSCA();
        System.assertEquals(1,i,'expected 1 but found '+i);
    }
}