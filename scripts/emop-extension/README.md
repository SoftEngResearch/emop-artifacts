This is a Maven extension to run EMOP without changing the pom.xml
file in a project.

Instructions:

1. mvn package
2. mvn_dir=$(mvn -version | grep ^Maven | cut -d: -f2 | tr -d ' ')
3. mkdir -p ${mvn_dir}/lib/ext # may need sudo access
4. cp target/emop-extension-1.0-SNAPSHOT.jar ${mvn_dir}/lib/ext
5. # All done
