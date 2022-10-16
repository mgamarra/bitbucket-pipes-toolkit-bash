
echo  $(date +%y%m%d.%H%M.%S) >> README.md

git add . && git commit -am "more tests $(date +%y%m%d.%H%M.%S)" && git push

#curl -k -i -u mgamarra:@34NovaSenha562208 https://jenkins.devops.valorpro.com.br/view/NewArchitecture/job/NEW%20-%20Valor%20DataQuotesAPI%20Pipeline/buildWithParameters?token=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