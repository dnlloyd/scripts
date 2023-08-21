# https://eksctl.io/usage/iam-identity-mappings/
eksctl get iamidentitymapping --cluster myeks --region=us-east-2

# ARN                                                              USERNAME                           GROUPS                              ACCOUNT
# arn:aws:iam::123456789012:role/Developers                        developer                          system:masters
# arn:aws:iam::123456789012:role/Argocd-myeks                      argocd                             system:masters
# arn:aws:iam::123456789012:role/myeks-EKSManagedNodeGroup  system:node:{{EC2PrivateDNSName}}  system:bootstrappers,system:nodes
# arn:aws:iam::123456789012:role/overlay-deployer-myeks            overlay-deployer                   system:masters
# arn:aws:iam::123456789012:role/Administrator                     admin                              system:masters
# arn:aws:iam::123456789012:role/DevOps                            devops                             system:masters

eksctl delete iamidentitymapping --cluster myeks --region=us-east-2 --arn arn:aws:iam::123456789012:role/Developer

eksctl create iamidentitymapping --cluster myeks --region=us-east-2 \
  --arn arn:aws:iam::123456789012:role/Developer \
  --username developer --group developers \
  --no-duplicate-arns

# As Developer
aws eks update-kubeconfig --region us-east-2 --name myeks --alias myeks --kubeconfig ./kube-config
kubectl config use-context myeks --kubeconfig ./kube-config
kubectl config current-context --kubeconfig ./kube-config
kubectl get nodes --kubeconfig='./kube-config'
