# Практическая работа 3

Базовая ветка разработки — `dev`. Изменения вносятся через pull request из тематической ветки.
Workflow `.github/workflows/python-ci.yml` запускается при `pull_request` в `dev` и при `push` в `dev`.

Проверки: `python -m unittest discover -s tests -v` и `python -m pylint calculator.py tests --fail-under=9.0`.
Отчёт Pylint сохраняется как артефакт `pylint-report`. Ошибки анализатора не подавляются.
