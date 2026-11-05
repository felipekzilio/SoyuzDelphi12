# Soyuz Delphi 12

Projeto em Delphi para Windows dedicado ao fluxo de inicialização e monitoramento do Riot Client e da sessão do League of Legends.

## Visão geral

Este projeto organiza a execução em etapas para:

- validar a presença do arquivo `pass.txt`;
- verificar a licença local/externa;
- localizar automaticamente o instalador do Riot Client;
- iniciar o cliente oficial do Riot;
- monitorar a sessão do League of Legends;
- registrar e controlar serviços relacionados ao Vanguard quando solicitado;
- operar com proxy local em modo opcional;
- gravar logs de execução em console e arquivo.

## Funcionalidades principais

- leitura do arquivo `pass.txt` ao lado do executável;
- validação de licença via backend configurado;
- detecção automática do Riot Client nos caminhos padrão do Windows;
- lançamento do cliente oficial com parâmetros de inicialização;
- monitoramento de processos com `Tool Help API`;
- espera por `LeagueClient.exe` com timeout configurável;
- detecção do início/fim do processo `League of Legends.exe`;
- encerramento opcional de processos do Riot com `--kill-riot`;
- serviço/registro VGC quando habilitado por flag;
- desinstalação do Vanguard com `--remove-vanguard`;
- proxy HTTP local em modo opcional;
- logs de etapas e eventos de execução.

## Estrutura do projeto

- `Soyuz.dpr` — ponto de entrada da aplicação;
- `Soyuz.dproj` — projeto Delphi;
- `src/Core` — argumentos, configuração, logger e controle de serviço;
- `src/License` — leitura da licença/pass e validação;
- `src/Network` — cliente HTTP e proxy local;
- `src/Riot` — inicialização do Riot Client e manipulação do Vanguard;
- `src/Session` — monitoramento e gestão da sessão;
- `src/Launcher` — inicialização de processos;
- `build/` — artefatos compilados e arquivos de saída.

## Requisitos

- Delphi 12 (Athens) ou equivalente compatível;
- Windows 10/11 x64;
- acesso administrativo para operações que envolvam serviços e remoção do Vanguard;
- projeto configurado para compilação Win64;

## Compilação

Abra o projeto no Delphi e compile em modo Release, preferencialmente para Win64:

1. abra `Soyuz.dproj`;
2. selecione arquitetura `Win64`;
3. compile o projeto;
4. gere o executável em `build/Win64/Base` ou na pasta de saída configurada.

## Uso

```bat
Soyuz.exe --check-pass
Soyuz.exe --riot
Soyuz.exe --kill-riot
Soyuz.exe --kill-riot --riot
Soyuz.exe --remove-vanguard
Soyuz.exe --help
```

### Flags principais

- `--check-pass` — valida se o arquivo `pass.txt` existe e não está vazio;
- `--riot` — inicia o Riot Client oficial e monitora a sessão;
- `--kill-riot` — encerra os processos do Riot e, quando aplicável, para os serviços do Vanguard;
- `--remove-vanguard` — limpa processos e tenta remover o Vanguard;
- `--proxy` — habilita o proxy HTTP local;
- `--register-vgc` — registra/inicializa o serviço VGC;
- `--validate-license` — valida a licença no backend configurado;
- `--help` — exibe as opções disponíveis.

## Configuração

A aplicação lê variáveis de ambiente e o arquivo `pass.txt` no mesmo diretório do executável.

Exemplo de variáveis:

```bat
SOYUZ_BACKEND_URL=http://localhost:8080
SOYUZ_LICENSE_KEY=sua-chave
SOYUZ_PROXY_HOST=127.0.0.1
SOYUZ_PROXY_PORT=8080
SOYUZ_VGC_SERVICE_PATH=C:\caminho\para\vgc.exe
```

## Logs

A aplicação grava logs de etapas em console e também em arquivo local de saída, conforme a configuração do projeto.

## Observações importantes

- o programa foi concebido para Windows e depende do ambiente do sistema operacional;
- operações de remoção de serviços e encerramento de processos podem exigir privilégios administrativos;
- o fluxo de inicialização foi projetado para ser monitorado e controlar a sessão quando necessário;
- sempre teste em um ambiente controlado antes de usar em produção ou em máquinas que não sejam de sua responsabilidade.

## Licença

Este projeto é disponibilizado para fins de estudo, manutenção e desenvolvimento local. Ajustes finais de uso, distribuição e publicação devem respeitar as políticas do ambiente e dos serviços terceiros utilizados.

## Autor

Projeto mantido em ambiente local de desenvolvimento Delphi.
