package edu.illinois.extension;

import java.io.File;
import java.io.IOException;
import java.util.List;

import org.apache.maven.AbstractMavenLifecycleParticipant;
import org.apache.maven.MavenExecutionException;
import org.apache.maven.execution.MavenSession;
import org.codehaus.plexus.component.annotations.Component;
import org.apache.maven.model.Dependency;
import org.apache.maven.project.MavenProject;
import org.apache.maven.model.Plugin;
import org.codehaus.plexus.util.xml.Xpp3Dom;
import org.apache.maven.model.PluginExecution;

// your extension must be a "Plexus" component so mark it with the annotation
@Component( role = AbstractMavenLifecycleParticipant.class, hint = "mop")
public class MOPExtension extends AbstractMavenLifecycleParticipant
{

    final String MOP_AGENT_STRING="/javamop-agent-emop/javamop-agent-emop/1.0/javamop-agent-emop-1.0.jar";

    @Override
    public void afterSessionStart( MavenSession session )
        throws MavenExecutionException
    {
        // System.out.println("OWOLABI(AfterSessionStart): ");
    }

    @Override
    public void afterSessionEnd( MavenSession session )
        throws MavenExecutionException
    {
        // System.out.println("OWOLABI(AfterSessionEnd): ");
    }

    @Override
    public void afterProjectsRead( MavenSession session )
        throws MavenExecutionException
    {
        System.out.println("Modifying surefire to add JavaMOP...");
        boolean found = false;
        for (MavenProject project : session.getProjects()) {
	    List<Dependency> dependencyList = project.getDependencies();
            for (Dependency dependency : dependencyList) {
                if (dependency.getArtifactId().equals("junit") && !dependency.getVersion().equals("4.13.2")) {
                    dependency.setVersion("4.13.2");
                }
            }
	    Dependency rvMinimizationDependency = new Dependency();
	    rvMinimizationDependency.setGroupId("edu.cornell");
	    rvMinimizationDependency.setArtifactId("test-time-listener");
	    rvMinimizationDependency.setVersion("1.0-SNAPSHOT");
	    dependencyList.add(rvMinimizationDependency);
            for (Plugin plugin : project.getBuildPlugins()) {
                if (plugin.getArtifactId().equals("maven-surefire-plugin") && plugin.getGroupId().equals("org.apache.maven.plugins")) {
                    found = true;
		    String version = plugin.getVersion();
		    if (version == null || version.startsWith("2.0") || version.startsWith("2.1")) {
			System.out.println("Found version of surefire less than 2.20, replacing with 2.20");
			plugin.setVersion("2.20");
		    }
                    System.out.println("=====Version:: " + plugin.getVersion());
                    Xpp3Dom config = (Xpp3Dom)plugin.getConfiguration();
                    if (config != null) {
                        Xpp3Dom argLine = config.getChild("argLine");
                        if (argLine != null) {
                            String currentArgLine = argLine.getValue();
                            System.out.println("=====Current ArgLine:: " + currentArgLine);
                            argLine.setValue("-javaagent:" + session.getLocalRepository().getBasedir() + MOP_AGENT_STRING + " " + argLine.getValue());
                        } else {
                            config.addChild(getNewArgLine(session));
                        }
                    } else {
                        config = new Xpp3Dom("configuration");
                        config.addChild(getNewArgLine(session));
                    }
		    config.addChild(getNewPropertiesWithListener(config));
		    plugin.setConfiguration(config);
                    for (PluginExecution execution : plugin.getExecutions()) {
                        System.out.println("=====Version:: " + plugin.getExecutions());
                        execution.setConfiguration(config);
                    }
                }
            }
        }
    }

    public Xpp3Dom getNewArgLine(MavenSession session) {
        Xpp3Dom argLine = new Xpp3Dom("argLine");
        argLine.setValue("-javaagent:" + session.getLocalRepository().getBasedir() + MOP_AGENT_STRING);
        return argLine;
    }

    public Xpp3Dom getNewPropertiesWithListener(Xpp3Dom surefireConfig) {
        Xpp3Dom properties = (surefireConfig.getChild("properties") != null)
                ? surefireConfig.getChild("properties") : new Xpp3Dom("properties");
        Xpp3Dom property = new Xpp3Dom("property");
        Xpp3Dom name = new Xpp3Dom("name");
        name.setValue("listener");
        Xpp3Dom value = new Xpp3Dom("value");
        value.setValue("edu.cornell.TestTimeListener");
        property.addChild(name);
        property.addChild(value);
        properties.addChild(property);

        for(int i = 0; i < surefireConfig.getChildren().length; i++) {
            if(surefireConfig.getChildren()[i].getName().equals("properties")) {
                surefireConfig.removeChild(i);
                break;
            }
        }
        return properties;
    }

}
