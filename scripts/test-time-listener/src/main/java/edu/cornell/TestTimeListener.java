package edu.cornell;

import java.text.SimpleDateFormat;
import java.util.Date;

import org.junit.runner.Description;
import org.junit.runner.Result;
import org.junit.runner.notification.RunListener;

public class TestTimeListener extends RunListener {

    SimpleDateFormat timeFormatter = new SimpleDateFormat("yyyy-MM-dd-HH-mm-ss");

    @Override
    public void testRunStarted(Description description) throws Exception {
        System.out.println("[TestTimeListener] Test run start: " + timeFormatter.format(new Date()));
    }

    @Override
    public void testRunFinished(Result result) throws Exception {
        System.out.println("[TestTimeListener] Test run end: " + timeFormatter.format(new Date()));
    }
}
