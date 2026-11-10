<div align="center">

<img src="src/Assets/nook.png" width="96" alt="Ícone do Nook" />

# Nook

**Um mini player de vidro fosco para o Spotify que mora num cantinho da sua tela.**

Pause, pule e veja o que está tocando sem nunca mais abrir o Spotify.

[![Download](https://img.shields.io/github/v/release/solanosolutions/nook?label=download&color=1ED760&style=for-the-badge)](https://github.com/solanosolutions/nook/releases/latest)
[![Plataforma](https://img.shields.io/badge/plataforma-Windows%20%7C%20macOS%20beta-0078D4?style=for-the-badge)](#-download)
[![Licença](https://img.shields.io/github/license/solanosolutions/nook?style=for-the-badge&color=555)](LICENSE)
[![Estrelas](https://img.shields.io/github/stars/solanosolutions/nook?style=for-the-badge&color=f5c518)](https://github.com/solanosolutions/nook/stargazers)

<img src="docs/demo.gif" alt="Demonstração do Nook: vidro fosco em repouso, nítido no hover, ondas e barras ao vivo" />

**🆕 Nook para macOS, beta público:** o mesmo mini player de vidro, agora no Mac. [Teste e conte o que achou](https://github.com/solanosolutions/nook/releases/tag/v1.6.0-beta.1) · Windows: [v1.5.0](https://github.com/solanosolutions/nook/releases/tag/v1.5.0) com vidro Fosco, Frozen e Liquid.

[**Download**](https://github.com/solanosolutions/nook/releases/latest) · [Recursos](#-recursos) · [Como usar](#-como-usar) · [Dúvidas](#-dúvidas-frequentes) · [Roadmap](#-roadmap) · [English](README.md)

</div>

---

## 🆕 Novidades da [v1.5.0](https://github.com/solanosolutions/nook/releases/tag/v1.5.0)

- 🧊 **Três estilos de vidro.** Escolha **Fosco** (o clássico), **Frozen** (desfoque mais forte e frio, com um granulado fino de gelo, ainda mais discreto sobre qualquer fundo) ou **Liquid** (um vidro vivo, com borda de luz, brilho especular no topo e um reflexo suave na cor da capa). Configurações → Aparência → Vidro.

<details>
<summary>Versões anteriores</summary>

- **v1.4.0** · 🫧 Modo recolhido (só capa e play até você passar o mouse) e links do GitHub/Instagram com a versão no rodapé do menu.
- **v1.3.0** · ↕️ Layout vertical, esconder quando pausado e botão esconder.
- **v1.2.0** · ⏱️ Timer de foco, 🌐 interface em inglês e português, cantos do blur arredondados corrigidos.

</details>

## Por que o Nook?

Eu escuto música o dia inteiro enquanto trabalho. Toda vez que queria pausar ou pular, tinha que caçar o Spotify na barra de tarefas: um app inteiro aberto só para apertar um botão. Os mini players que testei eram pesados, feios ou pediam login com chave de API.

Então criei o que eu queria: **minimalista, bonito e invisível até você precisar dele.**

- 🪶 **Levíssimo.** ~30–60 MB de RAM e **menos de 1% de CPU**, mesmo com o visualizador ao vivo. O próprio Spotify usa 10× mais.
- 🔑 **Zero configuração.** Sem login, sem chave de API, sem vincular conta. Abriu, funcionou.
- 🫥 **Não atrapalha.** Não aparece na barra de tarefas nem no Alt+Tab, e se esconde sozinho quando você assiste a um filme em tela cheia.

## ✨ Recursos

| | |
|---|---|
| 🎨 **Três estilos** | **Minimalist** (vidro fosco + barras ao vivo), **Old School** (vidro Frozen, só a capa, como um MP3 player de 2010) e **Refined** (vidro Liquid + ondas ao vivo). O mais transparente possível em repouso; nítido e sólido assim que o mouse chega. |
| 🎵 **Visualizador ao vivo** | Barras ou ondas que reagem ao áudio *de verdade*, capturado **só do Spotify** (notificações e vídeos não interferem). |
| 🎨 **Cor da capa** | Barra de progresso e visualizador assumem a cor dominante da capa atual. |
| 📜 **Título rolando** | Nomes longos rolam suavemente; passe o mouse para congelar. |
| 🖱️ **Roda = volume** | A roda do mouse sobre o player muda **só o volume do player** (Spotify, navegador...), não o do PC inteiro. |
| 🎬 **Respeita a tela cheia** | Some sozinho quando um filme, jogo ou apresentação entra em tela cheia no monitor dele. |
| 💤 **Some quando pausado** | Ficou pausado um tempo (1, 5 ou 15 min)? Ele sai da frente e volta no próximo play. Ou use o botão esconder. |
| ↕️ **Horizontal ou vertical** | Escolha uma barra larga ou um cartão em pé com a capa grande, ótimo ao lado de uma barra de tarefas vertical. |
| 📌 **Pin** | O player completo vem fixado por padrão. Solte o pin e ele encolhe para uma pílula só com a capa e o play; passou o mouse, o player inteiro abre, tirou, ele recolhe de novo. |
| 🧲 **Arraste para onde quiser** | Gruda nas bordas da tela e lembra a posição. |
| 🎛️ **Configuração simples** | Escolha o estilo, alguns botões opcionais (aleatório, repetir, progresso, abrir Spotify), o layout e o tamanho. Sempre no topo, sem ajustes finos. |
| ⏱️ **Timer de foco** | Opcional: uma pílula de vidro acima do player. 5, 10, 25 min ou o tempo que você digitar; um toque suave quando acaba. |
| 🔗 **Links e versão no menu** | O rodapé das configurações mostra a versão que você está usando, além do GitHub e do Instagram. |
| 🌐 **Inglês e português** | Segue o idioma do Windows automaticamente. |
| 🚀 **Inicia com o Windows** | Opcional, um clique. |

<div align="center">
<img src="docs/shot-hover.png" width="420" alt="Nook no hover" />&nbsp;&nbsp;<img src="docs/shot-bars.png" width="420" alt="Nook com barras ao vivo" />
</div>

## 📥 Download

1. Baixe o **`Nook.exe`** na [última versão](https://github.com/solanosolutions/nook/releases/latest).
2. Coloque em qualquer pasta (ex.: `Documentos\Nook`) e dê dois cliques.
3. Pronto. Toque algo no Spotify e o Nook aparece no canto inferior direito.

Sem instalador e sem precisar instalar o .NET: vai tudo dentro de um único `.exe`.

> **"O Windows protegeu o computador"?** O Nook é gratuito e de código aberto, mas ainda não tem assinatura digital (os certificados são caros), então o SmartScreen avisa sobre qualquer app novo sem assinatura. Clique em **Mais informações → Executar assim mesmo**. Você pode conferir o arquivo pelo SHA-256 publicado em cada versão, ou [compilar você mesmo](#-compilar-a-partir-do-código).

**Requisitos:** Windows 10 (2004+) ou Windows 11, x64. O visualizador ao vivo precisa do **Windows 11**; no Windows 10 o Nook mostra a capa do álbum.

### 🍎 macOS (beta público)

1. Baixe o **`Nook-1.6.0-beta.2.dmg`** na [versão beta para macOS](https://github.com/solanosolutions/nook/releases/tag/v1.6.0-beta.2).
2. Abra e arraste o **Nook** para **Aplicativos**.
3. O beta ainda não é notarizado pela Apple, então o macOS bloqueia a primeira abertura. Abra o Nook uma vez e clique em **Concluído** (não em "Mover para o Lixo"), depois vá em **Ajustes do Sistema → Privacidade e Segurança**, role até o fim e clique em **Abrir Mesmo Assim**. No macOS 13 ou 14 também dá para clicar com o **botão direito no Nook → Abrir**.
4. Permita o Nook controlar o Spotify quando o macOS pedir. O Nook fica na barra de menus, não no Dock.
5. Quando uma música tocar no estilo **Minimalist** ou **Refined**, o macOS pede para o Nook gravar o áudio do sistema. Clique em **Permitir**: o Nook só escuta o Spotify, para as barras e ondas acompanharem a música, e nada é gravado nem enviado. Se recusou, ligue o Nook em **Ajustes do Sistema → Privacidade e Segurança → Gravação de Tela e Áudio do Sistema** (em *Somente Gravação de Áudio do Sistema*). Sem a permissão as barras continuam se mexendo, só que fora do ritmo. Precisa do macOS 14.2 ou mais novo.

**Requisitos:** macOS 13 Ventura ou mais novo, Apple Silicon ou Intel, com o app do Spotify instalado. O beta traz o player, os três estilos (Minimalist, Old School, Refined) com Liquid Glass nativo no macOS 26, barras e ondas que seguem a música, o pin para recolher o player, a cor da capa, o volume na rolagem e o ícone na barra de menus; o layout vertical e o timer de foco vêm em seguida. Achou um problema? [Conte pra gente](https://github.com/solanosolutions/nook/issues/new/choose).

> 🐧 **Linux mais para frente.** [Dê uma estrela](https://github.com/solanosolutions/nook/stargazers) ou acompanhe as versões para saber quando chegar.

## 🖱️ Como usar

| Ação | O que faz |
|---|---|
| **Arrastar** | Move o player para qualquer lugar |
| **Duplo clique** ou **botão direito** | Abre as configurações |
| **Roda do mouse** | Sobe / desce o volume do player |
| **Clique na barra de progresso** | Pula para aquele ponto da música |
| **Botão esconder** (—) | Esconde na hora; volta no próximo play |
| **Botão pin** | Solte para encolher na pílula (passar o mouse abre); fixe de novo para deixar aberto |
| **Ícone na bandeja** | Mostrar / esconder, configurações, sair |

<details>
<summary><b>⚙️ Ver o menu de configurações</b></summary>
<br>
<img src="docs/shot-settings.png" width="300" alt="Menu de configurações do Nook" />
</details>

## 🔒 Privacidade

- O Nook conversa **só com o Windows**: ele lê o que está tocando pelos mesmos controles de mídia que o painel de volume do Windows usa.
- O visualizador analisa o áudio **na memória, em tempo real**. Nada é gravado, salvo ou enviado.
- Sem telemetria, sem contas, sem acesso à internet. As configurações ficam em `%AppData%\Nook\settings.json`.

## ❓ Dúvidas frequentes

<details>
<summary><b>Funciona com outros apps além do Spotify?</b></summary>

Sim. O Nook prioriza o Spotify, mas se ele não estiver aberto, controla o que estiver tocando (YouTube no navegador, outros players), e a roda do mouse mexe no volume desse app (ou no do sistema, se não achar o app).
</details>

<details>
<summary><b>Preciso do Spotify Premium?</b></summary>

Não. O Nook usa só os controles de mídia padrão do Windows, então funciona com o Spotify gratuito também.
</details>

<details>
<summary><b>O player sumiu!</b></summary>

Provavelmente ele se escondeu sozinho: ou algo está em tela cheia, ou nenhum player está aberto (Spotify fechado). Use o ícone da bandeja para mostrá-lo, ou desligue essas opções nas configurações.
</details>

<details>
<summary><b>Como desinstalo?</b></summary>

Desligue "Iniciar com o Windows" nas configurações, saia pelo ícone da bandeja e apague o `Nook.exe` e a pasta `%AppData%\Nook`. Só isso, nada mais é alterado.
</details>

## 🗺️ Roadmap

- [x] Widget de vidro fosco, arrastar, ímã nas bordas, bandeja
- [x] Visualizador de áudio ao vivo (captura só do Spotify)
- [x] Cor da capa, título rolando, volume só do Spotify
- [x] Esconde em tela cheia / quando nada está aberto
- [x] 🌐 Interface em inglês e português (segue o idioma do Windows)
- [x] ⏱️ Timer de foco (5 / 10 / 25 min ou personalizado), discreto como o player
- [x] ↕️ Layout vertical e esconder quando pausado
- [x] 🫧 Modo recolhido (só capa e play até você passar o mouse)
- [x] 🧊 Estilos de vidro: Fosco, Frozen e Liquid
- [x] 🎨 Três estilos fixos: Minimalist, Old School e Refined
- [ ] 🍎 Versão para macOS ([beta público disponível](https://github.com/solanosolutions/nook/releases/tag/v1.6.0-beta.1))
- [ ] 🐧 Versão para Linux
- [ ] ❤️ Botão de curtir (login opcional no Spotify)
- [ ] Versões com assinatura digital

Tem uma ideia? [Abra uma issue](https://github.com/solanosolutions/nook/issues/new/choose). Sugestões são muito bem-vindas.

## 🛠️ Compilar a partir do código

Precisa do [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0) no Windows.

```powershell
git clone https://github.com/solanosolutions/nook.git
cd nook
dotnet run --project src -c Release                                    # roda
powershell -ExecutionPolicy Bypass -File tools\publish.ps1             # gera o Nook.exe independente
```

**macOS:** num Mac com Xcode 15+, rode `mac/scripts/bundle.sh` (detalhes em [mac/README.md](mac/README.md)).

**Como funciona:** WPF/.NET 8. Informações e controles de reprodução vêm do [System Media Transport Controls](https://learn.microsoft.com/uwp/api/windows.media.control) do Windows; o visualizador usa o *process loopback* do WASAPI para capturar só o áudio do Spotify e uma FFT pequena; o volume usa as sessões do Core Audio. Sem dependências de terceiros.

## 🤝 Contribuindo

Issues e pull requests são bem-vindos! Relatos de bug com passos para reproduzir (e o `%AppData%\Nook\error.log`, se existir) ajudam muito.

## ⭐ Curtiu?

Se o Nook deixou seu dia um pouco mais tranquilo, **[deixe uma estrela](https://github.com/solanosolutions/nook/stargazers)**. É de graça, leva um clique e ajuda outras pessoas a encontrá-lo. 🙏

---

<div align="center">
<sub>Feito com ☕ e 🎧 por <a href="https://github.com/solanosolutions">Lucas Solano</a> · Licença MIT<br>
O Nook é um projeto independente, sem afiliação, endosso ou patrocínio do Spotify AB. Spotify é marca registrada do Spotify AB.</sub>
</div>
