# Third-party notices

LaTeX Snip is licensed under the GNU AGPL v3.0 or later (see `LICENSE`). It includes or links the following third-party components.

## Texo formula-recognition model

- Model weights: [alephpi/FormulaNet](https://huggingface.co/alephpi/FormulaNet), revision `b2668efe5112082846fde4d446b9bfaab3989533` (ONNX encoder, decoder and tokenizer).
- Image preprocessing in `TexoPreprocessor.swift` and parts of `LatexCleanup.swift` are ported from [Texo-web](https://github.com/alephpi/Texo-web).
- Project: [alephpi/Texo](https://github.com/alephpi/Texo)
- Copyright (C) 2025-present Sicheng Mao
- License: GNU Affero General Public License v3.0 (same text as `LICENSE`).
- The model is fine-tuned from [PaddlePaddle PP-FormulaNet-S](https://huggingface.co/PaddlePaddle/PP-FormulaNet-S) (Apache License 2.0).

## ONNX Runtime

- [microsoft/onnxruntime](https://github.com/microsoft/onnxruntime) via [onnxruntime-swift-package-manager](https://github.com/microsoft/onnxruntime-swift-package-manager)
- ONNX Runtime's own third-party notices: <https://github.com/microsoft/onnxruntime/blob/main/ThirdPartyNotices.txt>

```
MIT License

Copyright (c) Microsoft Corporation

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Yams

- [jpsim/Yams](https://github.com/jpsim/Yams)

```
The MIT License (MIT)

Copyright (c) 2016 JP Simard.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
