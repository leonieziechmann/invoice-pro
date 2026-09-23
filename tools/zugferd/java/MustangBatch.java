import java.io.BufferedReader;
import java.io.FileDescriptor;
import java.io.FileOutputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.io.PrintStream;
import java.nio.charset.StandardCharsets;
import org.mustangproject.validator.ZUGFeRDValidator;

/**
 * Validates many Factur-X / ZUGFeRD / XRechnung XML files in a single JVM with
 * Mustang's {@link ZUGFeRDValidator} (XSD plus the official Schematron rules).
 *
 * <p>Starting the Mustang CLI costs about three seconds per file; a warm JVM
 * validates a file in a few dozen milliseconds. The corpus runner therefore
 * keeps one instance of this program running and streams file paths to it.
 *
 * <p>Protocol: read one file path per line from standard input. For every path,
 * write
 *
 * <pre>
 * &#64;&#64;&#64;FILE &lt;path&gt; &lt;milliseconds&gt;
 * &lt;Mustang's XML validation report&gt;
 * &#64;&#64;&#64;END
 * </pre>
 *
 * to standard output and flush, so a caller can use it interactively (one
 * path at a time) or as a batch (all paths at once). Mustang's own logging is
 * kept off standard output.
 *
 * <p>Build and run (the corpus runner does this automatically):
 *
 * <pre>
 * javac -cp Mustang-CLI.jar -d out MustangBatch.java
 * java -cp Mustang-CLI.jar:out MustangBatch &lt; paths.txt
 * </pre>
 */
public final class MustangBatch {
  private MustangBatch() {}

  public static void main(String[] args) throws Exception {
    PrintStream out =
        new PrintStream(new FileOutputStream(FileDescriptor.out), true, StandardCharsets.UTF_8);
    // Mustang logs to standard output; the protocol needs it for itself.
    System.setOut(new PrintStream(OutputStream.nullOutputStream()));

    BufferedReader in =
        new BufferedReader(new InputStreamReader(System.in, StandardCharsets.UTF_8));
    for (String line; (line = in.readLine()) != null; ) {
      String path = line.trim();
      if (path.isEmpty()) {
        continue;
      }
      long start = System.nanoTime();
      String report;
      try {
        report = new ZUGFeRDValidator().validate(path);
      } catch (Throwable e) {
        report = "<crash>" + escape(String.valueOf(e)) + "</crash>";
      }
      long millis = (System.nanoTime() - start) / 1_000_000;
      out.println("@@@FILE " + path + " " + millis);
      out.println(report);
      out.println("@@@END");
      out.flush();
    }
  }

  private static String escape(String text) {
    return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;");
  }
}
