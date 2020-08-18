<h1><b>Changing Timezone for Kubernetes Windows Based Nodes</b></h1>
<!-- wp:paragraph -->
<p>Having the ability to containerize your Windows based application and running them on Kubernetes is a great options, specially for companies who are not looking forward to modernize their application using a cross platforms frameworks.</p>
<!-- /wp:paragraph -->

<!-- wp:paragraph -->
<p>While containerizing Windows based application is pretty much easy, being able to control the time zone of the windows based nodes is kind of tricky specially when using Azure Kubernetes Services (AKS), or Amazon EKS. hosted on a different region.</p>
<!-- /wp:paragraph -->

<!-- wp:paragraph -->
<p>lets go through one of the options we have to overcome this issue.</p>
<!-- /wp:paragraph -->

<!-- wp:paragraph -->
<p>The idea is to create a K8s DaemonSet which is going to ensure a specific pod to be deployed to each and every node that exists or being added to the cluster, that pod will simply connect to its host node and set the timezone to your proffered one.</p>
<!-- /wp:paragraph -->

<!-- wp:heading -->
<h2>Preparing a docker image for you the DaemonSet Pod</h2>
<!-- /wp:heading -->

<!-- wp:paragraph -->
<p>First you need to have Docker Desktop downloaded and installed on your development machine.</p>
<!-- /wp:paragraph -->

<!-- wp:paragraph {"align":"center"} -->
<p class="has-text-align-center"><a href="https://www.docker.com/products/docker-desktop" data-type="URL" data-id="https://www.docker.com/products/docker-desktop">https://www.docker.com/products/docker-desktop</a></p>
<!-- /wp:paragraph -->

<!-- wp:paragraph -->
<p>Make sure you switch to windows based engine. now create an empty folder in which we are going to use to build our image, lets name it TimeZoneImage.</p>
<!-- /wp:paragraph -->
<!-- wp:paragraph -->
<p>we are going to need a tool which will help us ssh inside the node from the pod, one advantage plink is the ability to automate passing in the username and password of an SSH session, download plink.exe 64bits from the link below and store it inside TimeZoneImage folder.</p>
<!-- /wp:paragraph -->

<!-- wp:paragraph {"align":"center"} -->
<p class="has-text-align-center"><a href="https://www.chiark.greenend.org.uk/~sgtatham/putty/latest.html" data-type="URL" data-id="https://www.chiark.greenend.org.uk/~sgtatham/putty/latest.html">https://www.chiark.greenend.org.uk/~sgtatham/putty/latest.html</a></p>
<!-- /wp:paragraph -->

<!-- wp:paragraph -->
<p>we need to pass in a script which will be executed remotely on the server so create a new file bat file lets call it script.bat</p>
<!-- /wp:paragraph -->

<!-- wp:paragraph {"fontSize":"medium"} -->
<p class="has-medium-font-size"><strong>script.bat</strong></p>
<!-- /wp:paragraph -->

<!-- wp:syntaxhighlighter/code -->
<pre class="wp-block-syntaxhighlighter-code">powershell Set-
-Name '#TimeZone#'; echo "Done execting inside the Node!...";echo "Changing Time Zone to: #TimeZone#";</pre>
<!-- /wp:syntaxhighlighter/code -->

<!-- wp:paragraph -->
<p>This will simply set the time zone to your TimeZone Env Variable.</p>
<!-- /wp:paragraph -->

<!-- wp:paragraph -->
<p>Next we need a file to act as an entrypoint for our container, lets create that file and call it start.ps1</p>
<!-- /wp:paragraph -->

<!-- wp:paragraph {"fontSize":"medium"} -->
<p class="has-medium-font-size"><strong>start.ps1</strong></p>
<!-- /wp:paragraph -->

<!-- wp:syntaxhighlighter/code -->
<pre class="wp-block-syntaxhighlighter-code">echo "Start Plink with Node $env:nodeIP"
$filePath = 'script.bat'
$tempFilePath = "$env:TEMP\$($filePath | Split-Path -Leaf)"
$find = '#TimeZone#'
$replace = $env:timezone

(Get-Content -Path $filePath) -replace $find, $replace | Add-Content -Path $tempFilePath

Remove-Item -Path $filePath
Move-Item -Path $tempFilePath -Destination $filePath

echo y | c:\\plink.exe $env:nodeIP -l $env:user -pw $env:pwd -m script.bat
Echo "Done Plink"
</pre>
<!-- /wp:syntaxhighlighter/code -->

<!-- wp:paragraph -->
<p>Next the DockerFile would look like this</p>
<!-- /wp:paragraph -->

<!-- wp:syntaxhighlighter/code -->
<pre class="wp-block-syntaxhighlighter-code">FROM mcr.microsoft.com/windows/servercore:ltsc2019
COPY plink.exe /
COPY script.bat /
COPY start.ps1 /
SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; Set-ExecutionPolicy Unrestricted -Force;"]
ENTRYPOINT ["powershell.exe", "c:\\start.ps1"] 
</pre>
<!-- /wp:syntaxhighlighter/code -->

<!-- wp:paragraph -->
<p>The folder should look like this</p>
<!-- /wp:paragraph -->

<!-- wp:image {"id":385,"sizeSlug":"large"} -->
<figure class="wp-block-image size-large"><img src="https://mohammedumar.files.wordpress.com/2020/08/1.png?w=149" alt="" class="wp-image-385"/></figure>
<!-- /wp:image -->

<!-- wp:paragraph -->
<p>Open power-shell and from inside the folder run the following command to build the image, tag it and push it to your favourite container register, (In this case I will use Azure Container Registry)</p>
<!-- /wp:paragraph -->

<!-- wp:code -->
<pre class="wp-block-code"><code>docker build .
docker tag &lt;yourimage> &lt;youracr>.azurecr.io/&lt;yourimagename>
docker push &lt;yourimage> &lt;youracr>.azurecr.io/&lt;yourimagename></code></pre>
<!-- /wp:code -->

<!-- wp:paragraph -->
<p>once done we are ready to create our DaemonSet</p>
<!-- /wp:paragraph -->

<!-- wp:quote {"className":"is-style-default","ampFitText":true} -->
<amp-fit-text layout="fixed-height" min-font-size="16" max-font-size="16" height="80"><blockquote class="wp-block-quote is-style-default"><p><code>A <em>DaemonSet</em> ensures</code> that all (or some) Nodes run a copy of a Pod. As nodes are added to the cluster, Pods are added to them. As nodes are removed from the cluster, those Pods are garbage collected. Deleting a DaemonSet will clean up the Pods it created.</p><cite><a href="https://kubernetes.io/docs/concepts/workloads/controllers/daemonset/">https://kubernetes.io/docs/concepts/workloads/controllers/daemonset/</a></cite></blockquote></amp-fit-text>
<!-- /wp:quote -->

<!-- wp:paragraph -->
<p>User the following Yaml file to deploy DaemonSet:</p>
<!-- /wp:paragraph -->

<!-- wp:code -->
<pre class="wp-block-code"><code>apiVersion: apps/v1
kind: DaemonSet
metadata:
  namespace: kube-system
  name: wintimezonedaemon-ds
spec:
  selector:
    matchLabels:
      name: wintimezonedaemon-ds
  template:
    metadata:
      labels:
        name: wintimezonedaemon-ds
    spec:
      nodeSelector:
        "beta.kubernetes.io/os": windows
      containers:
      - name: wintimezonedaemon
        env:
          - name: nodeIP
            valueFrom:
              fieldRef:
                fieldPath: status.hostIP
          - name: timezone
            value: &lt;yourpreferedtimezone>
          - name: user
            value: &lt;your-vmss-or-node-user>
          - name: pwd
            value: &lt;your-vmss-or-node-password>
        image: &lt;yourimage> &lt;youracr>.azurecr.io/&lt;yourimagename>:latest
        resources:
          limits:
            cpu: 300m
            memory: 400M
          requests:
            cpu: 150m
            memory: 200M</code></pre>
<!-- /wp:code -->

<!-- wp:paragraph -->
<p>Note the environment variables, the first one is to pass in the NodeIP to the pod which is going to be used to communicate with the node, the second env variable is where you provide your preferred time zone the third and fourth env variables are basically your windows node username and password if you need to reset this you can go to the VMSS on azure portal (Assuming AK) and choose "Reset Password", .</p>
<!-- /wp:paragraph -->

<!-- wp:paragraph -->
<p>once done you can simply execute the following command to create your DaemonSet</p>
<!-- /wp:paragraph -->

<!-- wp:code -->
<pre class="wp-block-code"><code>kubectl create -f daemonset.yaml</code></pre>
<!-- /wp:code -->
